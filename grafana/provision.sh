#!/usr/bin/env bash
set -euo pipefail

# PayStream Phase 6 — Grafana Provisioning Script
# Provisions datasources, dashboards, and alerts via Grafana HTTP API.
# Prerequisites: Grafana running at localhost:3000 (SSH tunnel to ClickHouse EC2).

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_AUTH="${GRAFANA_AUTH:-admin:paystream}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== PayStream Grafana Provisioning ==="
echo "Target: ${GRAFANA_URL}"

# ---------- Helper ----------
api() {
  local method="$1" endpoint="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sf -X "$method" \
      -H "Content-Type: application/json" \
      -u "${GRAFANA_AUTH}" \
      "${GRAFANA_URL}${endpoint}" \
      -d "$data"
  else
    curl -sf -X "$method" \
      -u "${GRAFANA_AUTH}" \
      "${GRAFANA_URL}${endpoint}"
  fi
}

# ---------- 1. Datasources ----------
echo ""
echo "--- Creating Datasources ---"

for ds_file in "${SCRIPT_DIR}/datasources/"*.json; do
  ds_name=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['name'])" "$ds_file")
  echo "  Creating datasource: ${ds_name}"
  if api POST "/api/datasources" "$(cat "$ds_file")" > /dev/null 2>&1; then
    echo "    OK (created)"
  else
    echo "    Already exists or updated"
    # Try update by name
    ds_id=$(api GET "/api/datasources/name/${ds_name}" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
    if [[ -n "$ds_id" ]]; then
      api PUT "/api/datasources/${ds_id}" "$(cat "$ds_file")" > /dev/null 2>&1 && echo "    OK (updated)" || echo "    WARN: update failed"
    fi
  fi
done

# ---------- 2. Create Alert Folder ----------
echo ""
echo "--- Creating Alert Folder ---"
api POST "/api/folders" '{"uid":"paystream","title":"PayStream Alerts"}' > /dev/null 2>&1 \
  && echo "  Folder created" \
  || echo "  Folder already exists"

# ---------- 3. Dashboards ----------
echo ""
echo "--- Importing Dashboards ---"

for db_file in "${SCRIPT_DIR}/dashboards/"*.json; do
  db_title=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('dashboard',d).get('title','unknown'))" "$db_file")
  echo "  Importing: ${db_title}"
  if api POST "/api/dashboards/db" "$(cat "$db_file")" > /dev/null 2>&1; then
    echo "    OK"
  else
    echo "    WARN: import may have failed — check Grafana UI"
  fi
done

# ---------- 4. Alert Rules ----------
echo ""
echo "--- Importing Alert Rules ---"

for alert_file in "${SCRIPT_DIR}/alerts/"*.json; do
  alert_title=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['title'])" "$alert_file")
  echo "  Creating alert: ${alert_title}"

  # Wrap in Grafana alerting API format
  alert_payload=$(python3 -c "
import json, sys
rule = json.load(open(sys.argv[1]))
payload = {
    'name': rule.get('ruleGroup', 'paystream-alerts'),
    'interval': '1m',
    'rules': [rule]
}
print(json.dumps(payload))
" "$alert_file")

  folder_uid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('folderUID','paystream'))" "$alert_file")
  if api POST "/api/ruler/grafana/api/v1/rules/${folder_uid}" "$alert_payload" > /dev/null 2>&1; then
    echo "    OK"
  else
    echo "    WARN: alert creation may have failed — check Grafana UI"
  fi
done

echo ""
echo "=== Provisioning Complete ==="
echo "Open ${GRAFANA_URL}/dashboards to verify."
