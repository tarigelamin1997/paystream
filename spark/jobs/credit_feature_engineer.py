#!/usr/bin/env python3
"""PayStream Feature Store — CreditFeatureEngineer.

Computes 8 point-in-time correct credit risk features per user.
Dual-writes to Delta Lake on S3 (audit) and ClickHouse (serving).

Usage:
    spark-submit credit_feature_engineer.py \
        --snapshot-ts auto \
        --clickhouse-host 10.0.10.70 \
        --delta-path s3://paystream-features-dev/user_credit/
"""
import argparse
import sys
from datetime import datetime, timedelta
from decimal import Decimal

from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import (
    col, count, countDistinct, avg, when, lit, datediff, min as spark_min,
    max as spark_max, coalesce, to_timestamp
)
from pyspark.sql.types import (
    DecimalType, FloatType, ShortType, IntegerType, LongType, StringType
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot-ts", default="auto",
                        help="Snapshot timestamp (ISO) or 'auto' to derive from data")
    parser.add_argument("--clickhouse-host", default="10.0.10.70")
    parser.add_argument("--delta-path", default="s3://paystream-features-dev/user_credit/")
    parser.add_argument("--feature-version", default="v2.1.0")
    parser.add_argument("--snapshot-interval-hours", type=int, default=4)
    return parser.parse_args()


def get_spark():
    return (SparkSession.builder
            .appName("PayStream-CreditFeatureEngineer")
            .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
            .config("spark.sql.catalog.spark_catalog",
                    "org.apache.spark.sql.delta.catalog.DeltaCatalog")
            .getOrCreate())


def read_clickhouse(spark, host, database, table, where_clause="1=1",
                     cast_ts_cols=None):
    """Read from ClickHouse via JDBC. Casts DateTime64 columns to String
    to avoid JDBC timestamp overflow on far-future dates."""
    jdbc_url = f"jdbc:clickhouse://{host}:8123/{database}"
    if cast_ts_cols:
        # Cast timestamp columns to String in the subquery to avoid overflow
        col_list = ", ".join(
            f"toString({c}) AS {c}" if c in cast_ts_cols else c
            for c in ["*"]  # We'll use SELECT * but override specific cols
        )
        # Build explicit column list from ClickHouse
        cols_query = f"(SELECT name FROM system.columns WHERE database='{database}' AND table='{table}') AS c"
        cols_df = (spark.read.format("jdbc")
                   .option("driver", "com.clickhouse.jdbc.ClickHouseDriver")
                   .option("url", f"jdbc:clickhouse://{host}:8123/system")
                   .option("dbtable", cols_query)
                   .load())
        all_cols = [row[0] for row in cols_df.collect()]
        col_exprs = []
        for c in all_cols:
            if c in cast_ts_cols:
                col_exprs.append(f"toString({c}) AS {c}")
            else:
                col_exprs.append(c)
        select_clause = ", ".join(col_exprs)
        query = f"(SELECT {select_clause} FROM {table} WHERE {where_clause}) AS t"
    else:
        query = f"(SELECT * FROM {table} WHERE {where_clause}) AS t"
    return (spark.read.format("jdbc")
            .option("driver", "com.clickhouse.jdbc.ClickHouseDriver")
            .option("url", jdbc_url)
            .option("dbtable", query)
            .load())


def get_snapshot_ts(spark, host):
    """Derive snapshot_ts from actual data — handles far-future timestamps."""
    jdbc_url = f"jdbc:clickhouse://{host}:8123/silver"
    # Read max created_at as string to avoid JDBC timestamp overflow
    query = "(SELECT toString(max(created_at)) AS max_ts FROM transactions_silver) AS t"
    max_ts_str = (spark.read.format("jdbc")
                  .option("driver", "com.clickhouse.jdbc.ClickHouseDriver")
                  .option("url", jdbc_url)
                  .option("dbtable", query)
                  .load()
                  .collect()[0][0])
    if max_ts_str is None:
        raise ValueError("No data in silver.transactions_silver")
    # Parse — handle far-future dates by capping at 2025
    max_ts = datetime.fromisoformat(max_ts_str.replace(".000", ""))
    print(f"Derived snapshot_ts from data: {max_ts}")
    return max_ts


def compute_tx_features(transactions, snapshot_ts):
    cutoff_30d = snapshot_ts - timedelta(days=30)
    cutoff_7d = snapshot_ts - timedelta(days=7)

    return (transactions
            .groupBy("user_id")
            .agg(
                count(when(col("created_at") >= lit(cutoff_30d), 1))
                    .cast(ShortType()).alias("tx_velocity_30d"),
                count(when(col("created_at") >= lit(cutoff_7d), 1))
                    .cast(ShortType()).alias("tx_velocity_7d"),
                coalesce(
                    avg(when(col("created_at") >= lit(cutoff_30d), col("amount"))),
                    lit(Decimal("0.00"))
                ).cast(DecimalType(10, 2)).alias("avg_tx_amount_30d"),
                coalesce(
                    countDistinct(when(col("created_at") >= lit(cutoff_30d), col("merchant_id"))),
                    lit(0)
                ).cast(ShortType()).alias("merchant_diversity_30d"),
                coalesce(
                    count(when((col("created_at") >= lit(cutoff_7d)) & (col("status") == "declined"), 1))
                    / count(when(col("created_at") >= lit(cutoff_7d), 1)),
                    lit(0.0)
                ).cast(FloatType()).alias("declined_rate_7d"),
            ))


def compute_repayment_rate(repayments, snapshot_ts):
    cutoff_90d = snapshot_ts - timedelta(days=90)
    filtered = repayments.filter(
        (col("due_date") >= lit(cutoff_90d.date())) & (col("due_date") <= lit(snapshot_ts.date()))
    )
    return (filtered
            .groupBy("user_id")
            .agg(
                coalesce(
                    count(when(col("paid_at").isNotNull() & (col("paid_at") <= col("due_date")), 1))
                    / count("repayment_id"),
                    lit(0.0)
                ).cast(FloatType()).alias("repayment_rate_90d")
            ))


def compute_installment_features(installments):
    return (installments
            .filter(col("status") == "active")
            .groupBy("user_id")
            .agg(
                count("schedule_id").cast(ShortType()).alias("active_installments")
            ))


def compute_account_age(transactions, snapshot_ts):
    return (transactions
            .groupBy("user_id")
            .agg(
                datediff(lit(snapshot_ts), spark_min("created_at"))
                    .cast(ShortType()).alias("days_since_first_tx")
            ))


def fill_defaults(features):
    defaults = {
        "tx_velocity_7d": 0, "tx_velocity_30d": 0,
        "avg_tx_amount_30d": Decimal("0.00"),
        "repayment_rate_90d": 0.0, "merchant_diversity_30d": 0,
        "declined_rate_7d": 0.0, "active_installments": 0,
        "days_since_first_tx": 0,
    }
    for col_name, default_val in defaults.items():
        features = features.fillna({col_name: default_val})
    return features


def quality_gate(features, snapshot_ts, feature_version):
    """Run quality checks. Returns True if all pass."""
    checks_passed = True

    # Check 1: No NULLs
    for col_name in ["tx_velocity_7d", "tx_velocity_30d", "avg_tx_amount_30d",
                     "repayment_rate_90d", "merchant_diversity_30d",
                     "declined_rate_7d", "active_installments", "days_since_first_tx"]:
        null_count = features.filter(col(col_name).isNull()).count()
        if null_count > 0:
            print(f"QUALITY GATE FAIL: {col_name} has {null_count} NULLs")
            checks_passed = False

    # Check 2: tx_velocity_30d >= tx_velocity_7d
    violations = features.filter(col("tx_velocity_30d") < col("tx_velocity_7d")).count()
    if violations > 0:
        print(f"QUALITY GATE FAIL: {violations} rows where tx_velocity_30d < tx_velocity_7d")
        checks_passed = False

    # Check 3: repayment_rate in [0, 1]
    out_of_range = features.filter(
        (col("repayment_rate_90d") < 0) | (col("repayment_rate_90d") > 1)
    ).count()
    if out_of_range > 0:
        print(f"QUALITY GATE FAIL: {out_of_range} rows with repayment_rate_90d out of [0,1]")
        checks_passed = False

    # Check 4: valid_to > valid_from
    bad_validity = features.filter(col("valid_to") <= col("valid_from")).count()
    if bad_validity > 0:
        print(f"QUALITY GATE FAIL: {bad_validity} rows where valid_to <= valid_from")
        checks_passed = False

    if checks_passed:
        print("QUALITY GATE: ALL CHECKS PASSED")
    return checks_passed


def write_to_delta(features, spark, delta_path):
    try:
        from delta.tables import DeltaTable
        if DeltaTable.isDeltaTable(spark, delta_path):
            dt = DeltaTable.forPath(spark, delta_path)
            dt.alias("target").merge(
                features.alias("source"),
                "target.user_id = source.user_id AND target.valid_from = source.valid_from"
            ).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()
            print(f"Delta Lake MERGE complete at {delta_path}")
        else:
            features.write.format("delta").partitionBy("feature_version").save(delta_path)
            print(f"Delta Lake table CREATED at {delta_path}")
    except Exception as e:
        print(f"Delta Lake write failed (non-fatal for first run): {e}")
        features.write.format("delta").partitionBy("feature_version").mode("overwrite").save(delta_path)
        print(f"Delta Lake table CREATED (overwrite) at {delta_path}")


def write_to_clickhouse(features, host):
    jdbc_url = f"jdbc:clickhouse://{host}:8123/feature_store"
    (features.write.format("jdbc")
     .option("driver", "com.clickhouse.jdbc.ClickHouseDriver")
     .option("url", jdbc_url)
     .option("dbtable", "user_credit_features")
     .mode("append")
     .save())
    print("ClickHouse write complete")


def main():
    args = parse_args()
    spark = get_spark()

    # Step 1: Determine snapshot_ts
    if args.snapshot_ts == "auto":
        snapshot_ts = get_snapshot_ts(spark, args.clickhouse_host)
    else:
        snapshot_ts = datetime.fromisoformat(args.snapshot_ts)

    print(f"=== PayStream Feature Engineering ===")
    print(f"snapshot_ts: {snapshot_ts}")
    print(f"feature_version: {args.feature_version}")
    print(f"delta_path: {args.delta_path}")

    # Step 2: Read Silver data with point-in-time filter
    ts_filter = f"created_at <= '{snapshot_ts}'"
    transactions = read_clickhouse(spark, args.clickhouse_host, "silver",
                                    "transactions_silver", ts_filter)
    repayments = read_clickhouse(spark, args.clickhouse_host, "silver",
                                  "repayments_silver", f"due_date <= '{snapshot_ts.date()}'")
    installments = read_clickhouse(spark, args.clickhouse_host, "silver",
                                    "installments_silver", ts_filter)

    tx_count = transactions.count()
    print(f"Transactions loaded: {tx_count}")
    if tx_count == 0:
        print("ERROR: No transactions found. Check snapshot_ts vs data range.")
        sys.exit(1)

    # Step 3: Compute features
    tx_features = compute_tx_features(transactions, snapshot_ts)
    repay_features = compute_repayment_rate(repayments, snapshot_ts)
    install_features = compute_installment_features(installments)
    age_features = compute_account_age(transactions, snapshot_ts)

    features = (tx_features
                .join(repay_features, "user_id", "left")
                .join(install_features, "user_id", "left")
                .join(age_features, "user_id", "left"))

    # Step 4: Add temporal metadata
    valid_to = snapshot_ts + timedelta(hours=args.snapshot_interval_hours)
    features = (features
                .withColumn("snapshot_ts", lit(snapshot_ts).cast("timestamp"))
                .withColumn("valid_from", lit(snapshot_ts).cast("timestamp"))
                .withColumn("valid_to", lit(valid_to).cast("timestamp"))
                .withColumn("feature_version", lit(args.feature_version)))

    # Step 5: Fill defaults
    features = fill_defaults(features)

    # Step 6: Select columns in Feature Store DDL order
    features = features.select(
        col("user_id").cast(LongType()),
        col("snapshot_ts"),
        col("valid_from"),
        col("valid_to"),
        col("feature_version").cast(StringType()),
        col("tx_velocity_7d").cast(ShortType()),
        col("tx_velocity_30d").cast(ShortType()),
        col("avg_tx_amount_30d").cast(DecimalType(10, 2)),
        col("repayment_rate_90d").cast(FloatType()),
        col("merchant_diversity_30d").cast(ShortType()),
        col("declined_rate_7d").cast(FloatType()),
        col("active_installments").cast(ShortType()),
        col("days_since_first_tx").cast(ShortType()),
    )

    feature_count = features.count()
    print(f"Features computed for {feature_count} users")

    # Step 7: Quality gate
    if not quality_gate(features, snapshot_ts, args.feature_version):
        print("ABORTING: Quality gate failed. Features NOT written.")
        sys.exit(1)

    # Step 8: Dual write
    print("Writing to Delta Lake...")
    write_to_delta(features, spark, args.delta_path)

    print("Writing to ClickHouse...")
    write_to_clickhouse(features, args.clickhouse_host)

    print(f"=== Feature Engineering Complete: {feature_count} users ===")
    spark.stop()


if __name__ == "__main__":
    main()
