#!/bin/bash
# Run dbt tests against ClickHouse via SSH tunnel through bastion.
# Usage: ./scripts/run_dbt_tests.sh
#
# dbt-clickhouse is not available in MWAA (C extension dependencies).
# This script provides the production-grade alternative: run dbt tests
# from any machine with dbt-clickhouse installed via SSH tunnel.
set -euo pipefail

BASTION_EIP=$(terraform -chdir=terraform output -raw bastion_eip 2>/dev/null || echo "56.228.74.219")
CH_IP=$(terraform -chdir=terraform output -raw clickhouse_private_ip 2>/dev/null || echo "10.0.10.70")
SSH_KEY="${SSH_KEY:-~/.ssh/paystream-bastion.pem}"

echo "Setting up SSH tunnel to ClickHouse ($CH_IP via $BASTION_EIP)..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -f -N \
  -L 9000:"${CH_IP}":9000 -L 8123:"${CH_IP}":8123 \
  ec2-user@"$BASTION_EIP"

cleanup() { pkill -f "ssh.*-L 9000:${CH_IP}" 2>/dev/null || true; }
trap cleanup EXIT

# Verify tunnel
curl -sf "http://localhost:8123/?query=SELECT+1" > /dev/null || { echo "ERROR: SSH tunnel failed"; exit 1; }
echo "Tunnel active."

echo ""
echo "Running dbt tests (target=dev → localhost:9000)..."
cd dbt/
dbt test --target dev 2>&1 | tee /tmp/dbt_test_output.txt

# Write results to gold.dq_results via tunnel
RESULT_LINE=$(grep -a "Done\. PASS=" /tmp/dbt_test_output.txt 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || echo "")
if [ -n "$RESULT_LINE" ]; then
  PASS=$(echo "$RESULT_LINE" | sed 's/.*PASS=\([0-9]*\).*/\1/')
  WARN=$(echo "$RESULT_LINE" | sed 's/.*WARN=\([0-9]*\).*/\1/')
  ERROR=$(echo "$RESULT_LINE" | sed 's/.*ERROR=\([0-9]*\).*/\1/')
  if [ "$ERROR" -gt 0 ]; then STATUS="fail"; elif [ "$WARN" -gt 0 ]; then STATUS="warn"; else STATUS="pass"; fi
  curl -sf "http://localhost:8123/" --data-binary \
    "INSERT INTO gold.dq_results VALUES (now64(3), 'dbt', 'dbt_test_suite_bastion', 'test_run', '${STATUS}', '{\"pass\":${PASS},\"warn\":${WARN},\"error\":${ERROR},\"source\":\"bastion_script\"}', ${PASS}, ${ERROR})"
  echo "DQ result written: status=${STATUS} pass=${PASS} warn=${WARN} error=${ERROR}"
else
  echo "WARNING: Could not parse dbt output — DQ result not written"
fi

echo ""
echo "=== Done ==="
