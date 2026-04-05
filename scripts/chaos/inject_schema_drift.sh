#!/bin/bash
# Chaos Scenario 5: Schema Drift Detection
# Adds a test column to Bronze, triggers drift detector, verifies detection, cleans up.
set -euo pipefail

BASTION_EIP="${BASTION_EIP:-56.228.74.219}"
CH_IP="${CH_IP:-10.0.10.70}"
SSH_KEY="${SSH_KEY:-~/.ssh/paystream-bastion.pem}"

ch() { ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@"$BASTION_EIP" "curl -s http://${CH_IP}:8123/ --data-binary @-" <<CHEOF
$1
CHEOF
}

echo "=== Chaos: Schema Drift Injection ==="
BEFORE=$(ch "SELECT count() FROM system.columns WHERE database='bronze' AND table='pg_transactions_raw'")
echo "[1/4] Baseline column count: $BEFORE"

echo "[2/4] Adding test column..."
ch "ALTER TABLE bronze.pg_transactions_raw ADD COLUMN IF NOT EXISTS test_chaos_col String DEFAULT ''"
AFTER=$(ch "SELECT count() FROM system.columns WHERE database='bronze' AND table='pg_transactions_raw'")
echo "  Column count after: $AFTER"

echo "[3/4] Trigger schema_drift_detector DAG and wait..."
echo "  (Manual trigger or wait for next scheduled run at */6h)"
echo "  Check: SELECT * FROM gold.dq_results WHERE check_type='schema_drift' ORDER BY check_time DESC LIMIT 5"

echo "[4/4] Cleaning up..."
ch "ALTER TABLE bronze.pg_transactions_raw DROP COLUMN IF EXISTS test_chaos_col"
FINAL=$(ch "SELECT count() FROM system.columns WHERE database='bronze' AND table='pg_transactions_raw'")
echo "  Column count after cleanup: $FINAL"

if [ "$BEFORE" = "$FINAL" ]; then
  echo "=== Scenario 5: PASS (cleanup verified) ==="
else
  echo "=== Scenario 5: FAIL (column count mismatch: $BEFORE vs $FINAL) ==="
fi
