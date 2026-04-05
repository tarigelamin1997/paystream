#!/bin/bash
# Chaos Scenario 2: Invalid Feature Serve-Time Validation
# Injects a row with repayment_rate=1.5 (violates [0,1] constraint),
# verifies FastAPI returns 503 with Pydantic error, checks Prometheus counter.
set -euo pipefail

BASTION_EIP="${BASTION_EIP:-56.228.74.219}"
CH_IP="${CH_IP:-10.0.10.70}"
SSH_KEY="${SSH_KEY:-~/.ssh/paystream-bastion.pem}"
ALB="http://paystream-fastapi-alb-1584201898.eu-north-1.elb.amazonaws.com"

ch() { ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@"$BASTION_EIP" "curl -s http://${CH_IP}:8123/ --data-binary @-" <<CHEOF
$1
CHEOF
}

echo "=== Chaos: Invalid Feature Injection ==="
echo "[1/4] Injecting invalid row (user 999999, repayment_rate=1.5)..."
ch "INSERT INTO feature_store.user_credit_features VALUES (999999, toDateTime64('2024-12-31 23:59:59', 3), toDateTime64('2024-12-31 23:59:59', 3), toDateTime64('2025-01-01 03:59:59', 3), 'v2.1.0', 5, 10, toDecimal64(1500.00, 2), toFloat32(1.5), 3, toFloat32(0.1), 2, 287, now())"

echo "[2/4] Querying FastAPI for invalid user..."
HTTP_CODE=$(curl -s -o /tmp/chaos_resp.json -w "%{http_code}" "$ALB/features/user/999999")
echo "  HTTP: $HTTP_CODE"
cat /tmp/chaos_resp.json

if [ "$HTTP_CODE" = "503" ]; then
  echo "  PASS: API correctly rejected invalid data with 503"
else
  echo "  FAIL: Expected 503, got $HTTP_CODE"
fi

echo "[3/4] Checking Prometheus counter..."
curl -s "$ALB/metrics" | grep "validation_failures_total "

echo "[4/4] Cleaning up..."
ch "ALTER TABLE feature_store.user_credit_features DELETE WHERE user_id = 999999"
sleep 5
REMAINING=$(ch "SELECT count() FROM feature_store.user_credit_features WHERE user_id = 999999")
echo "  Remaining rows: $REMAINING"

echo ""
echo "=== Scenario 2: $([ "$HTTP_CODE" = "503" ] && echo "PASS" || echo "FAIL") ==="
