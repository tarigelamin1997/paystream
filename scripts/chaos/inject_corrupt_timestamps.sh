#!/bin/bash
# Chaos Scenario 1: Corrupt Timestamp Injection (Bronze Layer)
# Inserts year-2299 rows into Bronze, verifies they don't reach Feature Store.
# WARNING: Direct INSERTs into _raw tables propagate through Bronze->Silver MVs.
# Cleanup removes from both Bronze and Silver.
set -euo pipefail

BASTION_EIP="${BASTION_EIP:-56.228.74.219}"
CH_IP="${CH_IP:-10.0.10.70}"
SSH_KEY="${SSH_KEY:-~/.ssh/paystream-bastion.pem}"

ch() { ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@"$BASTION_EIP" "curl -s http://${CH_IP}:8123/ --data-binary @-" <<CHEOF
$1
CHEOF
}

echo "=== Chaos: Corrupt Timestamp Injection ==="
BEFORE_B=$(ch "SELECT count() FROM bronze.pg_transactions_raw")
BEFORE_S=$(ch "SELECT count() FROM silver.transactions_silver")
echo "[1/5] Baseline: Bronze=$BEFORE_B, Silver=$BEFORE_S"

echo "[2/5] Injecting 3 corrupt rows (year 2299)..."
for id in 999901 999902 999903; do
  ch "INSERT INTO bronze.pg_transactions_raw VALUES ($id, $id, 1, toDecimal64(100, 2), 'SAR', 'approved', 100, 3, toDateTime64('2299-12-31 23:59:59', 3), 'c', 1700000000000, now())"
done

AFTER_B=$(ch "SELECT count() FROM bronze.pg_transactions_raw")
CORRUPT=$(ch "SELECT count() FROM bronze.pg_transactions_raw WHERE toYear(created_at) = 2299")
echo "  Bronze after: $AFTER_B (corrupt: $CORRUPT)"

echo "[3/5] Checking Feature Store (should be unaffected)..."
FS=$(ch "SELECT count() FROM feature_store.user_credit_features WHERE user_id IN (999901, 999902, 999903)")
echo "  Feature Store rows for chaos users: $FS"

echo "[4/5] Cleaning up Bronze + Silver..."
ch "ALTER TABLE bronze.pg_transactions_raw DELETE WHERE transaction_id IN (999901, 999902, 999903)"
ch "ALTER TABLE silver.transactions_silver DELETE WHERE transaction_id IN (999901, 999902, 999903)"
sleep 5

echo "[5/5] Verifying cleanup..."
FINAL_B=$(ch "SELECT count() FROM bronze.pg_transactions_raw")
FINAL_S=$(ch "SELECT count() FROM silver.transactions_silver")
echo "  Bronze: $FINAL_B (was $BEFORE_B), Silver: $FINAL_S (was $BEFORE_S)"

if [ "$BEFORE_B" = "$FINAL_B" ] && [ "$FS" = "0" ]; then
  echo "=== Scenario 1: PASS ==="
else
  echo "=== Scenario 1: FAIL (baseline mismatch or FS leak) ==="
fi
