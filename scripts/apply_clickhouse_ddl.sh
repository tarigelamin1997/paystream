#!/bin/bash
set -euo pipefail
# Apply ClickHouse Bronze DDL files in order via SSH tunnel
# Prerequisites: SSH tunnel to ClickHouse must be active

CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"

echo "=== Applying ClickHouse Bronze DDL ==="

for sql_file in clickhouse/bronze/*.sql; do
  echo "Applying: ${sql_file}"
  clickhouse-client \
    --host "${CLICKHOUSE_HOST}" \
    --port "${CLICKHOUSE_PORT}" \
    --multiquery \
    < "${sql_file}"
done

echo "=== DDL Applied Successfully ==="
echo "Verifying databases..."
clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" \
  --query "SHOW DATABASES"
echo "Verifying bronze tables..."
clickhouse-client --host "${CLICKHOUSE_HOST}" --port "${CLICKHOUSE_PORT}" \
  --query "SHOW TABLES FROM bronze"
