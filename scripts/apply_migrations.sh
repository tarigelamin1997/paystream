#!/bin/bash
set -euo pipefail
# PayStream — Schema Migration Runner
# Applies numbered SQL migrations from migrations/ directory
# Tracks applied versions in gold.schema_versions
#
# Usage: bash scripts/apply_migrations.sh
# Env vars: CH_HOST (default: 10.0.10.70), CH_PORT (default: 8123)

CH_HOST="${CH_HOST:-10.0.10.70}"
CH_PORT="${CH_PORT:-8123}"
CH_URL="http://${CH_HOST}:${CH_PORT}/"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-migrations}"

ch_query() {
    curl -sf "${CH_URL}" --data-binary "$1" 2>/dev/null
}

ch_select() {
    curl -sf "${CH_URL}?default_format=TabSeparated" --data-binary "$1" 2>/dev/null
}

# Ensure schema_versions table exists
ch_query "CREATE TABLE IF NOT EXISTS gold.schema_versions (
    version UInt32, description String,
    applied_at DateTime64(3) DEFAULT now64(3),
    checksum String, execution_time_ms UInt32
) ENGINE = MergeTree() ORDER BY version" || true

# Get last applied version
LAST_VERSION=$(ch_select "SELECT coalesce(max(version), 0) FROM gold.schema_versions" || echo "0")
LAST_VERSION=$(echo "$LAST_VERSION" | tr -d '[:space:]')
echo "Last applied version: ${LAST_VERSION}"

APPLIED=0
for f in $(ls "${MIGRATIONS_DIR}"/*.sql 2>/dev/null | sort); do
    VERSION=$(basename "$f" | grep -o '^[0-9]*' | sed 's/^0*//')
    [ -z "$VERSION" ] && continue

    if [ "$VERSION" -gt "$LAST_VERSION" ]; then
        DESCRIPTION=$(basename "$f" .sql | sed 's/^[0-9]*_//')
        CHECKSUM=$(md5sum "$f" | awk '{print $1}')

        echo "Applying migration ${VERSION}: ${DESCRIPTION} ..."
        START_S=$(date +%s)

        # Split file by semicolons and execute each statement
        while IFS= read -r stmt; do
            stmt=$(echo "$stmt" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            [ -z "$stmt" ] && continue
            # Skip comment-only statements
            echo "$stmt" | grep -qv '^--' || continue
            ch_query "$stmt" || { echo "  FAILED: $stmt"; exit 1; }
        done < <(sed 's/--[^\n]*//g' "$f" | tr '\n' ' ' | sed 's/;/;\n/g')

        END_S=$(date +%s)
        EXEC_MS=$(( (END_S - START_S) * 1000 ))

        ch_query "INSERT INTO gold.schema_versions VALUES (${VERSION}, '${DESCRIPTION}', now64(3), '${CHECKSUM}', ${EXEC_MS})"
        echo "  Applied in ~${EXEC_MS}ms (checksum: ${CHECKSUM})"
        APPLIED=$((APPLIED + 1))
    fi
done

echo "Done. ${APPLIED} migration(s) applied."
