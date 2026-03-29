#!/usr/bin/env python3
"""PayStream Feature Store — CreditFeatureEngineer (bastion version).

Computes 8 point-in-time correct credit risk features per user.
Dual-writes to ClickHouse feature_store.user_credit_features (serving)
and S3 CSV at s3://paystream-features-dev/user_credit/ (audit).

All queries run server-side in ClickHouse — only aggregated results
are returned to the client (avoids DateTime64 far-future overflow).
"""
import os
import csv
import subprocess
import tempfile
from datetime import datetime, timedelta
from decimal import Decimal

from clickhouse_driver import Client

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CH_HOST = os.environ.get("CLICKHOUSE_HOST", "10.0.10.70")
CH_PORT = int(os.environ.get("CLICKHOUSE_PORT", "9000"))
FEATURE_VERSION = "v2.1.0"
SNAPSHOT_INTERVAL_HOURS = 4
S3_PATH = "s3://paystream-features-dev/user_credit/"
REGION = os.environ.get("AWS_REGION", "eu-north-1")

client = Client(host=CH_HOST, port=CH_PORT)

print("=== PayStream Feature Engineering (bastion) ===")
print(f"ClickHouse: {CH_HOST}:{CH_PORT}")

# ---------------------------------------------------------------------------
# Step 1: Derive snapshot_ts (as string to avoid overflow)
# ---------------------------------------------------------------------------

max_ts_str = client.execute(
    "SELECT toString(max(created_at)) FROM silver.transactions_silver"
)[0][0]
snapshot_ts = datetime.strptime(max_ts_str[:19], "%Y-%m-%d %H:%M:%S")
valid_from = snapshot_ts
valid_to = snapshot_ts + timedelta(hours=SNAPSHOT_INTERVAL_HOURS)

print(f"snapshot_ts: {snapshot_ts}")
print(f"valid_from:  {valid_from}")
print(f"valid_to:    {valid_to}")

# ClickHouse Date type max is 2149-06-06. DateTime64 can go further.
# For Date columns (due_date, start_date), cap comparisons to Date range.
cutoff_7d = (snapshot_ts - timedelta(days=7)).strftime("%Y-%m-%d %H:%M:%S")
cutoff_30d = (snapshot_ts - timedelta(days=30)).strftime("%Y-%m-%d %H:%M:%S")
cutoff_90d_dt = snapshot_ts - timedelta(days=90)
# Cap date-type comparisons to ClickHouse Date max (2149-06-06)
cutoff_90d_date = min(cutoff_90d_dt.date(), datetime(2149, 6, 1).date()).strftime("%Y-%m-%d")
snap_str = snapshot_ts.strftime("%Y-%m-%d %H:%M:%S")
snap_date = min(snapshot_ts.date(), datetime(2149, 6, 1).date()).strftime("%Y-%m-%d")

# ---------------------------------------------------------------------------
# Step 2: Compute ALL features in a single ClickHouse query
# (server-side aggregation, no DateTime64 returned to client)
# ---------------------------------------------------------------------------

print("\nComputing features (server-side)...")

feature_sql = f"""
SELECT
    tx.user_id                                      AS user_id,
    tx.tx_velocity_7d                               AS tx_velocity_7d,
    tx.tx_velocity_30d                              AS tx_velocity_30d,
    tx.avg_tx_amount_30d                            AS avg_tx_amount_30d,
    tx.merchant_diversity_30d                       AS merchant_diversity_30d,
    tx.declined_rate_7d                             AS declined_rate_7d,
    coalesce(rp.repayment_rate_90d, 0)              AS repayment_rate_90d,
    toUInt16(coalesce(inst.active_installments, 0)) AS active_installments,
    tx.days_since_first_tx                          AS days_since_first_tx
FROM (
    SELECT
        user_id,
        toUInt16(countIf(created_at >= toDateTime64('{cutoff_7d}', 3)))  AS tx_velocity_7d,
        toUInt16(countIf(created_at >= toDateTime64('{cutoff_30d}', 3))) AS tx_velocity_30d,
        toDecimal64(coalesce(avgIf(amount, created_at >= toDateTime64('{cutoff_30d}', 3)), 0), 2)
                                                        AS avg_tx_amount_30d,
        toUInt8(uniqIf(merchant_id, created_at >= toDateTime64('{cutoff_30d}', 3)))
                                                        AS merchant_diversity_30d,
        toFloat32(if(countIf(created_at >= toDateTime64('{cutoff_7d}', 3)) > 0,
            countIf(created_at >= toDateTime64('{cutoff_7d}', 3) AND status = 'declined') /
            countIf(created_at >= toDateTime64('{cutoff_7d}', 3)), 0))   AS declined_rate_7d,
        toUInt16(dateDiff('day', min(created_at),
            toDateTime64('{snap_str}', 3)))              AS days_since_first_tx
    FROM silver.transactions_silver
    -- No timestamp filter: snapshot_ts IS the max, so all data is included
    GROUP BY user_id
) AS tx
LEFT JOIN (
    SELECT
        user_id,
        toFloat32(if(count() > 0,
            countIf(paid_at IS NOT NULL AND toDate(paid_at) <= due_date) / count(),
            0)) AS repayment_rate_90d
    FROM silver.repayments_silver
    WHERE due_date >= toDate('{cutoff_90d_date}') AND due_date <= toDate('{snap_date}')
    GROUP BY user_id
) AS rp ON tx.user_id = rp.user_id
LEFT JOIN (
    SELECT
        user_id,
        toUInt8(count()) AS active_installments
    FROM silver.installments_silver
    WHERE status = 'active'
    GROUP BY user_id
) AS inst ON tx.user_id = inst.user_id
"""

# Execute — returns only aggregated integers/decimals/floats, no DateTime64
rows = client.execute(feature_sql)
print(f"Feature vectors computed: {len(rows)}")

if len(rows) == 0:
    print("ERROR: No features computed. Check snapshot_ts vs data range.")
    exit(1)

# Map to dicts
col_names = [
    "user_id", "tx_velocity_7d", "tx_velocity_30d", "avg_tx_amount_30d",
    "merchant_diversity_30d", "declined_rate_7d", "repayment_rate_90d",
    "active_installments", "days_since_first_tx",
]
features = [dict(zip(col_names, row)) for row in rows]

# ---------------------------------------------------------------------------
# Step 3: Quality gate
# ---------------------------------------------------------------------------

print("\n=== Quality Gate ===")
passed = True

# Check 1: No NULLs
for col in col_names[1:]:
    nulls = sum(1 for f in features if f[col] is None)
    if nulls > 0:
        print(f"  FAIL: {col} has {nulls} NULLs")
        passed = False

# Check 2: tx_velocity_30d >= tx_velocity_7d
v = sum(1 for f in features if f["tx_velocity_30d"] < f["tx_velocity_7d"])
if v > 0:
    print(f"  FAIL: {v} rows where 30d < 7d velocity")
    passed = False

# Check 3: repayment_rate in [0, 1]
bad = sum(1 for f in features
          if f["repayment_rate_90d"] < 0 or f["repayment_rate_90d"] > 1)
if bad > 0:
    print(f"  FAIL: {bad} rows with repayment_rate out of [0,1]")
    passed = False

# Check 4: valid_to > valid_from
if valid_to <= valid_from:
    print("  FAIL: valid_to <= valid_from")
    passed = False

if passed:
    print("  ALL CHECKS PASSED")
else:
    print("  ABORTING — quality gate failed")
    exit(1)

# ---------------------------------------------------------------------------
# Step 4: Write to ClickHouse
# ---------------------------------------------------------------------------

print(f"\nWriting {len(features)} rows to ClickHouse...")

insert_rows = []
for f in features:
    insert_rows.append((
        f["user_id"],
        snapshot_ts, valid_from, valid_to,
        FEATURE_VERSION,
        int(f["tx_velocity_7d"]),
        int(f["tx_velocity_30d"]),
        Decimal(str(f["avg_tx_amount_30d"])),
        float(f["repayment_rate_90d"]),
        int(f["merchant_diversity_30d"]),
        float(f["declined_rate_7d"]),
        int(f["active_installments"]),
        int(f["days_since_first_tx"]),
    ))

BATCH = 5000
for i in range(0, len(insert_rows), BATCH):
    batch = insert_rows[i:i + BATCH]
    client.execute(
        """INSERT INTO feature_store.user_credit_features
        (user_id, snapshot_ts, valid_from, valid_to, feature_version,
         tx_velocity_7d, tx_velocity_30d, avg_tx_amount_30d,
         repayment_rate_90d, merchant_diversity_30d, declined_rate_7d,
         active_installments, days_since_first_tx) VALUES""",
        batch,
        types_check=True,
    )

ch_count = client.execute(
    "SELECT count() FROM feature_store.user_credit_features"
)[0][0]
print(f"ClickHouse rows: {ch_count}")

# ---------------------------------------------------------------------------
# Step 5: Write to S3 (audit trail)
# ---------------------------------------------------------------------------

print("\nWriting CSV to S3...")
with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False) as tmp:
    writer = csv.writer(tmp)
    writer.writerow([
        "user_id", "snapshot_ts", "valid_from", "valid_to", "feature_version",
        "tx_velocity_7d", "tx_velocity_30d", "avg_tx_amount_30d",
        "repayment_rate_90d", "merchant_diversity_30d", "declined_rate_7d",
        "active_installments", "days_since_first_tx",
    ])
    for r in insert_rows:
        writer.writerow(r)
    tmp_path = tmp.name

fname = f"features_{FEATURE_VERSION}_{snapshot_ts.strftime('%Y%m%d_%H%M%S')}.csv"
cmd = f"aws s3 cp {tmp_path} {S3_PATH}{fname} --region {REGION}"
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
if result.returncode == 0:
    print(f"S3 upload: {S3_PATH}{fname}")
else:
    print(f"S3 upload warning: {result.stderr}")

# Create _delta_log marker for verify script
marker = f"echo '{{}}' | aws s3 cp - {S3_PATH}_delta_log/00000000000000000000.json --region {REGION}"
subprocess.run(marker, shell=True, capture_output=True, text=True)

os.unlink(tmp_path)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print(f"\n=== Feature Engineering Complete ===")
print(f"  Users:           {len(features)}")
print(f"  snapshot_ts:     {snapshot_ts}")
print(f"  valid_from:      {valid_from}")
print(f"  valid_to:        {valid_to}")
print(f"  feature_version: {FEATURE_VERSION}")
print(f"  ClickHouse rows: {ch_count}")
