#!/usr/bin/env python3
"""Feature computation for MWAA — uses ClickHouse HTTP interface (no clickhouse-driver).
Called by feature_pipeline DAG as BashOperator."""
import os
import json
import requests
from datetime import datetime, timedelta

CH_HOST = os.environ.get("CLICKHOUSE_HOST", "10.0.10.70")
CH_PORT = os.environ.get("CLICKHOUSE_HTTP_PORT", "8123")
CH_URL = f"http://{CH_HOST}:{CH_PORT}/"
FEATURE_VERSION = "v2.1.0"
SNAPSHOT_INTERVAL_HOURS = 4


def ch_query(sql):
    resp = requests.post(CH_URL, params={"default_format": "JSONEachRow"},
                         data=sql.encode("utf-8"), timeout=60)
    if resp.status_code != 200:
        raise Exception(f"ClickHouse error {resp.status_code}: {resp.text[:500]}")
    if not resp.text.strip():
        return []
    return [json.loads(line) for line in resp.text.strip().split("\n") if line.strip()]


def ch_execute(sql):
    resp = requests.post(CH_URL, data=sql.encode("utf-8"), timeout=60)
    if resp.status_code != 200:
        raise Exception(f"ClickHouse error {resp.status_code}: {resp.text[:500]}")


def main():
    print("=== Feature Engineering (MWAA HTTP) ===")

    max_ts = ch_query("SELECT toString(max(created_at)) AS ts FROM silver.transactions_silver")[0]["ts"]
    snapshot_ts = datetime.strptime(max_ts[:19], "%Y-%m-%d %H:%M:%S")
    valid_from = snapshot_ts
    valid_to = snapshot_ts + timedelta(hours=SNAPSHOT_INTERVAL_HOURS)
    print(f"snapshot_ts: {snapshot_ts}")

    cutoff_7d = (snapshot_ts - timedelta(days=7)).strftime("%Y-%m-%d %H:%M:%S")
    cutoff_30d = (snapshot_ts - timedelta(days=30)).strftime("%Y-%m-%d %H:%M:%S")
    cutoff_90d_date = min((snapshot_ts - timedelta(days=90)).date(),
                          datetime(2149, 6, 1).date()).strftime("%Y-%m-%d")
    snap_date = min(snapshot_ts.date(), datetime(2149, 6, 1).date()).strftime("%Y-%m-%d")

    features = ch_query(f"""
    SELECT tx.user_id AS user_id, tx.tx_velocity_7d AS tx_velocity_7d,
        tx.tx_velocity_30d AS tx_velocity_30d, tx.avg_tx_amount_30d AS avg_tx_amount_30d,
        tx.merchant_diversity_30d AS merchant_diversity_30d, tx.declined_rate_7d AS declined_rate_7d,
        coalesce(rp.repayment_rate_90d, 0) AS repayment_rate_90d,
        toUInt16(coalesce(inst.active_installments, 0)) AS active_installments,
        tx.days_since_first_tx AS days_since_first_tx
    FROM (
        SELECT user_id,
            toUInt16(countIf(created_at >= toDateTime64('{cutoff_7d}', 3))) AS tx_velocity_7d,
            toUInt16(countIf(created_at >= toDateTime64('{cutoff_30d}', 3))) AS tx_velocity_30d,
            toDecimal64(coalesce(avgIf(amount, created_at >= toDateTime64('{cutoff_30d}', 3)), 0), 2) AS avg_tx_amount_30d,
            toUInt8(uniqIf(merchant_id, created_at >= toDateTime64('{cutoff_30d}', 3))) AS merchant_diversity_30d,
            toFloat32(if(countIf(created_at >= toDateTime64('{cutoff_7d}', 3)) > 0,
                countIf(created_at >= toDateTime64('{cutoff_7d}', 3) AND status = 'declined') /
                countIf(created_at >= toDateTime64('{cutoff_7d}', 3)), 0)) AS declined_rate_7d,
            toUInt16(dateDiff('day', min(created_at), toDateTime64('{snapshot_ts}', 3))) AS days_since_first_tx
        FROM silver.transactions_silver GROUP BY user_id
    ) AS tx
    LEFT JOIN (
        SELECT user_id,
            toFloat32(if(count() > 0,
                countIf(paid_at IS NOT NULL AND toDate(paid_at) <= due_date) / count(), 0)) AS repayment_rate_90d
        FROM silver.repayments_silver
        WHERE due_date >= toDate('{cutoff_90d_date}') AND due_date <= toDate('{snap_date}')
        GROUP BY user_id
    ) AS rp ON tx.user_id = rp.user_id
    LEFT JOIN (
        SELECT user_id, toUInt8(count()) AS active_installments
        FROM silver.installments_silver WHERE status = 'active' GROUP BY user_id
    ) AS inst ON tx.user_id = inst.user_id
    """)
    print(f"Features: {len(features)} users")
    if not features:
        raise ValueError("No features computed")

    vf = valid_from.strftime("%Y-%m-%d %H:%M:%S")
    vt = valid_to.strftime("%Y-%m-%d %H:%M:%S")
    ss = snapshot_ts.strftime("%Y-%m-%d %H:%M:%S")

    vals = []
    for f in features:
        vals.append(
            f"({f['user_id']},'{ss}','{vf}','{vt}','{FEATURE_VERSION}',"
            f"{f['tx_velocity_7d']},{f['tx_velocity_30d']},{f['avg_tx_amount_30d']},"
            f"{f['repayment_rate_90d']},{f['merchant_diversity_30d']},"
            f"{f['declined_rate_7d']},{f['active_installments']},{f['days_since_first_tx']})"
        )
    for i in range(0, len(vals), 1000):
        batch = ",".join(vals[i:i + 1000])
        ch_execute(f"""INSERT INTO feature_store.user_credit_features
            (user_id,snapshot_ts,valid_from,valid_to,feature_version,
             tx_velocity_7d,tx_velocity_30d,avg_tx_amount_30d,
             repayment_rate_90d,merchant_diversity_30d,declined_rate_7d,
             active_installments,days_since_first_tx) VALUES {batch}""")

    count = ch_query("SELECT count() AS c FROM feature_store.user_credit_features")[0]["c"]
    print(f"Feature Store rows: {count}")
    print("=== Complete ===")


if __name__ == "__main__":
    main()
