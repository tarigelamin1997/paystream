#!/bin/bash
set -euo pipefail
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"

echo "=== Applying Feature Store DDL ==="
for sql_file in clickhouse/feature_store/*.sql; do
  echo "Applying: ${sql_file}"
  clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" --multiquery < "${sql_file}"
done
echo "=== Feature Store DDL Applied ==="
clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" --query "SHOW TABLES FROM feature_store"
