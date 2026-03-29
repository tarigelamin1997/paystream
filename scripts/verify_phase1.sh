#!/bin/bash
set -euo pipefail
# PayStream Phase 1 Validation — 12 checks

REGION="${AWS_REGION:-eu-north-1}"
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"
SCHEMA_REGISTRY_URL="${SCHEMA_REGISTRY_URL:-http://localhost:8081}"
DEBEZIUM_PG_URL="${DEBEZIUM_PG_URL:-http://localhost:8083}"
DEBEZIUM_MONGO_URL="${DEBEZIUM_MONGO_URL:-http://localhost:8083}"

PASSED=0
FAILED=0

check() {
  local num="$1"
  local desc="$2"
  local result="$3"
  if [[ "${result}" == "PASS" ]]; then
    echo "  CHECK ${num}: PASS — ${desc}"
    PASSED=$((PASSED + 1))
  else
    echo "  CHECK ${num}: FAIL — ${desc} (${result})"
    FAILED=$((FAILED + 1))
  fi
}

echo "=== PayStream Phase 1 Verification ==="

# Check 1: VPC exists
VPC=$(aws ec2 describe-vpcs --region "${REGION}" --filters "Name=tag:Name,Values=paystream-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "NONE")
[[ "${VPC}" != "NONE" && "${VPC}" != "None" ]] && check 1 "VPC exists" "PASS" || check 1 "VPC exists" "${VPC}"

# Check 2: RDS available
RDS_STATUS=$(aws rds describe-db-instances --region "${REGION}" --db-instance-identifier paystream-rds --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null || echo "NOT_FOUND")
[[ "${RDS_STATUS}" == "available" ]] && check 2 "RDS available" "PASS" || check 2 "RDS available" "${RDS_STATUS}"

# Check 3: DocumentDB available
DOCDB_STATUS=$(aws docdb describe-db-clusters --region "${REGION}" --db-cluster-identifier paystream-docdb --query "DBClusters[0].Status" --output text 2>/dev/null || echo "NOT_FOUND")
[[ "${DOCDB_STATUS}" == "available" ]] && check 3 "DocumentDB available" "PASS" || check 3 "DocumentDB available" "${DOCDB_STATUS}"

# Check 4: MSK Serverless active
MSK_STATE=$(aws kafka list-clusters-v2 --region "${REGION}" --cluster-name-filter paystream-msk --query "ClusterInfoList[0].State" --output text 2>/dev/null || echo "NOT_FOUND")
[[ "${MSK_STATE}" == "ACTIVE" ]] && check 4 "MSK Serverless active" "PASS" || check 4 "MSK Serverless active" "${MSK_STATE}"

# Check 5: ClickHouse EC2 running
CH_STATE=$(aws ec2 describe-instances --region "${REGION}" --filters "Name=tag:Name,Values=paystream-clickhouse" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].State.Name" --output text 2>/dev/null || echo "NOT_FOUND")
[[ "${CH_STATE}" == "running" ]] && check 5 "ClickHouse EC2 running" "PASS" || check 5 "ClickHouse EC2 running" "${CH_STATE}"

# Check 6: Debezium PG connector RUNNING
PG_CONN_STATUS=$(curl -s "${DEBEZIUM_PG_URL}/connectors/paystream-pg-connector/status" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null || echo "NOT_FOUND")
[[ "${PG_CONN_STATUS}" == "RUNNING" ]] && check 6 "Debezium PG connector RUNNING" "PASS" || check 6 "Debezium PG connector RUNNING" "${PG_CONN_STATUS}"

# Check 7: Debezium Mongo connector RUNNING
MONGO_CONN_STATUS=$(curl -s "${DEBEZIUM_MONGO_URL}/connectors/paystream-mongo-connector/status" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null || echo "NOT_FOUND")
[[ "${MONGO_CONN_STATUS}" == "RUNNING" ]] && check 7 "Debezium Mongo connector RUNNING" "PASS" || check 7 "Debezium Mongo connector RUNNING" "${MONGO_CONN_STATUS}"

# Check 8: Bronze pg_transactions_raw count >= 400,000
TX_COUNT=$(clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" --query "SELECT count() FROM bronze.pg_transactions_raw" 2>/dev/null || echo "0")
[[ "${TX_COUNT}" -ge 400000 ]] && check 8 "bronze.pg_transactions_raw >= 400K" "PASS" || check 8 "bronze.pg_transactions_raw >= 400K" "count=${TX_COUNT}"

# Check 9: Bronze mongo_app_events_raw count >= 800,000
AE_COUNT=$(clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" --query "SELECT count() FROM bronze.mongo_app_events_raw" 2>/dev/null || echo "0")
[[ "${AE_COUNT}" -ge 800000 ]] && check 9 "bronze.mongo_app_events_raw >= 800K" "PASS" || check 9 "bronze.mongo_app_events_raw >= 800K" "count=${AE_COUNT}"

# Check 10: Schema Registry subjects >= 10
SR_COUNT=$(curl -s "${SCHEMA_REGISTRY_URL}/subjects" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
[[ "${SR_COUNT}" -ge 10 ]] && check 10 "Schema Registry subjects >= 10" "PASS" || check 10 "Schema Registry subjects >= 10" "count=${SR_COUNT}"

# Check 11: S3 buckets >= 6
S3_COUNT=$(aws s3 ls --region "${REGION}" | grep -c paystream || echo "0")
[[ "${S3_COUNT}" -ge 6 ]] && check 11 "S3 buckets >= 6" "PASS" || check 11 "S3 buckets >= 6" "count=${S3_COUNT}"

# Check 12: MWAA environment available
MWAA_STATUS=$(aws mwaa get-environment --region "${REGION}" --name paystream-mwaa --query "Environment.Status" --output text 2>/dev/null || echo "NOT_FOUND")
[[ "${MWAA_STATUS}" == "AVAILABLE" ]] && check 12 "MWAA environment available" "PASS" || check 12 "MWAA environment available" "${MWAA_STATUS}"

echo ""
echo "=== Results: ${PASSED}/12 passed, ${FAILED}/12 failed ==="

if [[ "${FAILED}" -gt 0 ]]; then
  exit 1
fi
echo "Phase 1 verification PASSED."
