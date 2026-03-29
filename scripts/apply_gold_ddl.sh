#!/bin/bash
set -euo pipefail
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"

echo "=== Applying Gold DDL ==="
for sql_file in clickhouse/gold/*.sql; do
  echo "Applying: ${sql_file}"
  clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" --multiquery < "${sql_file}"
done
echo "=== Gold DDL Applied ==="
clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" --query "SHOW TABLES FROM gold"
