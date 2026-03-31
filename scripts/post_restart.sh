#!/bin/bash
# scripts/post_restart.sh
# Run this ONCE after restarting EC2 instances.
# Verifies all services and restarts Debezium connectors if needed.
#
# Usage:
#   1. Start EC2 instances (ClickHouse + Bastion) from AWS Console
#   2. SSH to bastion, set up tunnels:
#      ssh -L 9000:<CH_IP>:9000 -L 3000:<CH_IP>:3000 -L 8083:<DEBEZIUM_PG_IP>:8083 ...
#   3. Run: bash scripts/post_restart.sh
set -euo pipefail

echo "=== PayStream Post-Restart Recovery ==="
echo ""

# 1. Verify ClickHouse
echo "[1/7] ClickHouse..."
CH_RESULT=$(clickhouse-client --host localhost --port 9000 --query "SELECT 1" 2>/dev/null || echo "FAIL")
if [ "$CH_RESULT" = "1" ]; then echo "  ✅ ClickHouse OK"; else echo "  ❌ ClickHouse FAIL — is SSH tunnel to port 9000 active?"; exit 1; fi

# 2. Verify Grafana
echo "[2/7] Grafana..."
GF_STATUS=$(curl -sf http://localhost:3000/api/health 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('database','FAIL'))" 2>/dev/null || echo "FAIL")
if [ "$GF_STATUS" = "ok" ]; then echo "  ✅ Grafana OK"; else echo "  ⚠️  Grafana not responding — is SSH tunnel to port 3000 active?"; fi

# 3. Verify FastAPI
echo "[3/7] FastAPI..."
ALB_DNS=$(terraform -chdir=terraform output -raw alb_dns_name 2>/dev/null || echo "")
if [ -n "$ALB_DNS" ]; then
    API_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" 2>/dev/null || echo "000")
    if [ "$API_CODE" = "200" ]; then echo "  ✅ FastAPI OK"; else echo "  ⚠️  FastAPI returned $API_CODE — ECS may still be starting, retry in 2 min"; fi
else
    echo "  ⚠️  Cannot read ALB DNS from Terraform — check manually"
fi

# 4. Verify MWAA
echo "[4/7] MWAA..."
MWAA_STATUS=$(aws mwaa get-environment --name paystream-mwaa --query 'Environment.Status' --output text --region eu-north-1 2>/dev/null || echo "FAIL")
if [ "$MWAA_STATUS" = "AVAILABLE" ]; then echo "  ✅ MWAA OK"; else echo "  ⚠️  MWAA status: $MWAA_STATUS"; fi

# 5. Restart Debezium connectors if needed
echo "[5/7] Debezium PG connector..."
PG_TASK_STATUS=$(curl -sf http://localhost:8083/connectors/paystream-pg-connector/status 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
tasks=d.get('tasks',[])
print(tasks[0]['state'] if tasks else 'NO_TASKS')
" 2>/dev/null || echo "UNREACHABLE")
echo "  PG task: $PG_TASK_STATUS"
if [ "$PG_TASK_STATUS" != "RUNNING" ]; then
    echo "  Restarting PG connector task 0..."
    curl -sf -X POST http://localhost:8083/connectors/paystream-pg-connector/tasks/0/restart 2>/dev/null || true
    sleep 15
    PG_TASK_STATUS=$(curl -sf http://localhost:8083/connectors/paystream-pg-connector/status 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks'][0]['state'])" 2>/dev/null || echo "STILL_FAILED")
    echo "  PG task after restart: $PG_TASK_STATUS"
    if [ "$PG_TASK_STATUS" != "RUNNING" ]; then
        echo ""
        echo "  ⚠️  PG connector still not running. Possible causes:"
        echo "  - RDS storage full (WAL accumulation during downtime)"
        echo "    Check: aws rds describe-db-instances --db-instance-identifier paystream-rds --query 'DBInstances[0].FreeStorageSpace' --output text --region eu-north-1"
        echo "    Fix:   aws rds modify-db-instance --db-instance-identifier paystream-rds --allocated-storage 50 --apply-immediately --region eu-north-1"
        echo "  - Replication slot corrupted — may need to delete and re-register connector"
    fi
else
    echo "  ✅ Debezium PG OK"
fi

echo "[5b/7] Debezium Mongo connector..."
MONGO_TASK_STATUS=$(curl -sf http://localhost:8084/connectors/paystream-mongo-connector/status 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
tasks=d.get('tasks',[])
print(tasks[0]['state'] if tasks else 'NO_TASKS')
" 2>/dev/null || echo "UNREACHABLE")
echo "  Mongo task: $MONGO_TASK_STATUS"
if [ "$MONGO_TASK_STATUS" = "UNREACHABLE" ]; then
    echo "  ⚠️  Cannot reach Mongo connector — check SSH tunnel to port 8084"
elif [ "$MONGO_TASK_STATUS" != "RUNNING" ]; then
    echo "  Restarting Mongo connector task 0..."
    curl -sf -X POST http://localhost:8084/connectors/paystream-mongo-connector/tasks/0/restart 2>/dev/null || true
    sleep 15
    MONGO_TASK_STATUS=$(curl -sf http://localhost:8084/connectors/paystream-mongo-connector/status 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks'][0]['state'])" 2>/dev/null || echo "STILL_FAILED")
    echo "  Mongo task after restart: $MONGO_TASK_STATUS"
else
    echo "  ✅ Debezium Mongo OK"
fi

# 6. Verify data integrity
echo "[6/7] Data integrity..."
BRONZE_COUNT=$(clickhouse-client --host localhost --port 9000 --query "SELECT count() FROM bronze.pg_transactions_raw" 2>/dev/null || echo "0")
echo "  Bronze transactions: $BRONZE_COUNT"
FS_COUNT=$(clickhouse-client --host localhost --port 9000 --query "SELECT count() FROM feature_store.user_credit_features" 2>/dev/null || echo "0")
echo "  Feature Store: $FS_COUNT"
DRIFT_COUNT=$(clickhouse-client --host localhost --port 9000 --query "SELECT count() FROM feature_store.drift_metrics" 2>/dev/null || echo "0")
echo "  Drift metrics: $DRIFT_COUNT"
GOLD_COUNT=$(clickhouse-client --host localhost --port 9000 --query "SELECT count() FROM gold.merchant_daily_kpis" 2>/dev/null || echo "0")
echo "  Gold merchant KPIs: $GOLD_COUNT"

# 7. Summary
echo ""
echo "[7/7] Summary"
echo "========================================"
echo "  ClickHouse:     $CH_RESULT"
echo "  Grafana:        $GF_STATUS"
echo "  FastAPI:        ${API_CODE:-unknown}"
echo "  MWAA:           $MWAA_STATUS"
echo "  Debezium PG:    $PG_TASK_STATUS"
echo "  Debezium Mongo: $MONGO_TASK_STATUS"
echo "  Bronze rows:    $BRONZE_COUNT"
echo "  Feature Store:  $FS_COUNT"
echo "  Drift metrics:  $DRIFT_COUNT"
echo "  Gold KPIs:      $GOLD_COUNT"
echo "========================================"
echo ""
echo "If Debezium PG is FAILED and RDS storage is low:"
echo "  aws rds modify-db-instance --db-instance-identifier paystream-rds --allocated-storage 50 --apply-immediately --region eu-north-1"
echo "  Then re-run this script after 5 minutes."
echo ""
echo "=== Recovery Complete ==="
