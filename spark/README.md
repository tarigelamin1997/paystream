# PayStream Feature Store — Spark Jobs

## Architecture

The Feature Store computes 8 point-in-time correct credit risk features per user from ClickHouse Silver tables, then dual-writes results to:

1. **Delta Lake on S3** (`s3://paystream-features-dev/user_credit/`) — audit trail and backfill source
2. **ClickHouse** (`feature_store.user_credit_features`) — low-latency serving via FastAPI

## Features Computed

| Feature | Window | Type |
|---|---|---|
| tx_velocity_7d | 7 days | ShortType |
| tx_velocity_30d | 30 days | ShortType |
| avg_tx_amount_30d | 30 days | Decimal(10,2) |
| repayment_rate_90d | 90 days | Float |
| merchant_diversity_30d | 30 days | ShortType |
| declined_rate_7d | 7 days | Float |
| active_installments | current | ShortType |
| days_since_first_tx | all-time | ShortType |

## Running

### Via EMR Serverless (production)

```bash
# Set required environment variables
export EMR_ROLE_ARN="arn:aws:iam::role/paystream-emr-role"
export CLICKHOUSE_HOST="10.0.10.70"

# Submit job
./spark/scripts/submit_emr_job.sh

# Check status
./spark/scripts/check_job_status.sh
```

### Via spark-submit (local/testing)

```bash
spark-submit \
    --jars clickhouse-jdbc-0.6.0-all.jar \
    --packages io.delta:delta-spark_2.12:3.2.0 \
    spark/jobs/credit_feature_engineer.py \
    --snapshot-ts auto \
    --clickhouse-host 10.0.10.70
```

## Snapshot Timestamp

The `--snapshot-ts auto` flag derives the snapshot timestamp from actual data via `SELECT max(created_at) FROM silver.transactions_silver`. This handles far-future timestamps (e.g., `2299-12-31`) correctly. You can also pass an explicit ISO timestamp.

## Quality Gate

Before writing, the job validates:
1. No NULLs in any feature column
2. tx_velocity_30d >= tx_velocity_7d (monotonicity)
3. repayment_rate_90d in [0, 1]
4. valid_to > valid_from (temporal correctness)

If any check fails, the job aborts without writing.
