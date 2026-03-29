#!/bin/bash
set -euo pipefail
# Register Debezium connectors via REST API
# Prerequisites: Debezium ECS services must be running

DEBEZIUM_PG_URL="${DEBEZIUM_PG_URL:-http://localhost:8083}"
DEBEZIUM_MONGO_URL="${DEBEZIUM_MONGO_URL:-http://localhost:8083}"

echo "=== Registering Debezium Connectors ==="

echo "[1/2] Registering PostgreSQL connector..."
curl -s -X POST "${DEBEZIUM_PG_URL}/connectors" \
  -H "Content-Type: application/json" \
  -d @debezium/connectors/pg_connector.json

echo ""
echo "[2/2] Registering DocumentDB connector..."
curl -s -X POST "${DEBEZIUM_MONGO_URL}/connectors" \
  -H "Content-Type: application/json" \
  -d @debezium/connectors/mongo_connector.json

echo ""
echo "=== Connector Registration Complete ==="

# Poll for connector status
echo "Waiting for connectors to start..."
for i in $(seq 1 12); do
  sleep 10
  PG_STATUS=$(curl -s "${DEBEZIUM_PG_URL}/connectors/paystream-pg-connector/status" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
  MONGO_STATUS=$(curl -s "${DEBEZIUM_MONGO_URL}/connectors/paystream-mongo-connector/status" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
  echo "  PG: ${PG_STATUS}, Mongo: ${MONGO_STATUS}"
  if [[ "${PG_STATUS}" == "RUNNING" && "${MONGO_STATUS}" == "RUNNING" ]]; then
    echo "Both connectors RUNNING."
    exit 0
  fi
done

echo "WARNING: Connectors not both RUNNING after 2 minutes."
exit 1
