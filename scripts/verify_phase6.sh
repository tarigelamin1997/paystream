#!/usr/bin/env bash
set -euo pipefail

# PayStream Phase 6 — Verification Script
# Checks all Phase 6 deliverables: Grafana files, stress test, docs.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$(command -v python 2>/dev/null || command -v python3 2>/dev/null || echo python3)"
# On Git Bash / MSYS2, convert POSIX paths to Windows for Python
if command -v cygpath > /dev/null 2>&1; then
  REPO_ROOT_PY="$(cygpath -w "${REPO_ROOT}")"
else
  REPO_ROOT_PY="${REPO_ROOT}"
fi
PASS=0
FAIL=0
TOTAL=0

check() {
  local num="$1" desc="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  if "$@" > /dev/null 2>&1; then
    echo "  [PASS] Check ${num}: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Check ${num}: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

file_exists() { test -f "$1"; }
dir_exists() { test -d "$1"; }

echo "=== PayStream Phase 6 Verification ==="
echo ""

# --- Grafana Datasources ---
echo "--- Grafana Datasources ---"
check 1 "ClickHouse datasource JSON exists" file_exists "${REPO_ROOT}/grafana/datasources/clickhouse.json"
check 2 "Prometheus datasource JSON exists" file_exists "${REPO_ROOT}/grafana/datasources/prometheus.json"

# --- Grafana Dashboards ---
echo "--- Grafana Dashboards ---"
check 3 "Dashboard 01 (Merchant Operations) exists" file_exists "${REPO_ROOT}/grafana/dashboards/01_merchant_operations.json"
check 4 "Dashboard 02 (Feature Store Health) exists" file_exists "${REPO_ROOT}/grafana/dashboards/02_feature_store_health.json"
check 5 "Dashboard 03 (Feature Drift Monitor) exists" file_exists "${REPO_ROOT}/grafana/dashboards/03_feature_drift_monitor.json"
check 6 "Dashboard 04 (Pipeline SLOs) exists" file_exists "${REPO_ROOT}/grafana/dashboards/04_pipeline_slos.json"
check 7 "Dashboard 05 (FinOps) exists" file_exists "${REPO_ROOT}/grafana/dashboards/05_finops.json"

# --- Grafana Alerts ---
echo "--- Grafana Alerts ---"
check 8 "Alert: feature_pipeline_stale exists" file_exists "${REPO_ROOT}/grafana/alerts/feature_pipeline_stale.json"
check 9 "Alert: feature_drift_detected exists" file_exists "${REPO_ROOT}/grafana/alerts/feature_drift_detected.json"
check 10 "Alert: settlement_mismatch exists" file_exists "${REPO_ROOT}/grafana/alerts/settlement_mismatch.json"
check 11 "Alert: approval_rate_drop exists" file_exists "${REPO_ROOT}/grafana/alerts/approval_rate_drop.json"
check 12 "Alert: ingestion_flatline exists" file_exists "${REPO_ROOT}/grafana/alerts/ingestion_flatline.json"

# --- Provision Script ---
echo "--- Provision Script ---"
check 13 "provision.sh exists" file_exists "${REPO_ROOT}/grafana/provision.sh"
check 14 "provision.sh is executable or has bash shebang" grep -q "#!/usr/bin/env bash" "${REPO_ROOT}/grafana/provision.sh"

# --- Stress Test ---
echo "--- Stress Test ---"
check 15 "stress_config.yaml exists" file_exists "${REPO_ROOT}/stress_test/stress_config.yaml"
check 16 "run_stress_test.py exists" file_exists "${REPO_ROOT}/stress_test/run_stress_test.py"
check 17 "measure_slos.py exists" file_exists "${REPO_ROOT}/stress_test/measure_slos.py"
check 18 "report_template.md exists" file_exists "${REPO_ROOT}/stress_test/report_template.md"
check 19 "slo_results.json exists" file_exists "${REPO_ROOT}/stress_test/results/slo_results.json"
check 20 "slo_results.json has 6 SLOs" test "$(${PYTHON} -c "import json,os; print(len(json.load(open(os.path.join(r'${REPO_ROOT_PY}','stress_test','results','slo_results.json')))['slos']))")" = "6"
check 21 "All SLOs met in results" ${PYTHON} -c "import json,os; d=json.load(open(os.path.join(r'${REPO_ROOT_PY}','stress_test','results','slo_results.json'))); assert d['all_slos_met']"

# --- Dashboard JSON Validity ---
echo "--- JSON Validity ---"
check 22 "All dashboard JSONs are valid" ${PYTHON} -c "
import json, glob, os
root = r'${REPO_ROOT_PY}'
for f in glob.glob(os.path.join(root,'grafana','dashboards','*.json')):
    json.load(open(f))
for f in glob.glob(os.path.join(root,'grafana','alerts','*.json')):
    json.load(open(f))
for f in glob.glob(os.path.join(root,'grafana','datasources','*.json')):
    json.load(open(f))
print('all valid')
"

# --- Dashboard Content ---
echo "--- Dashboard Content ---"
check 23 "Merchant dashboard uses _ingested_at" grep -q "_ingested_at" "${REPO_ROOT}/grafana/dashboards/01_merchant_operations.json"
check 24 "Drift dashboard queries drift_metrics" grep -q "drift_metrics" "${REPO_ROOT}/grafana/dashboards/03_feature_drift_monitor.json"
check 25 "FinOps dashboard queries system.parts" grep -q "system.parts" "${REPO_ROOT}/grafana/dashboards/05_finops.json"

# --- Screenshots ---
echo "--- Screenshots ---"
check 26 "Screenshot: merchant_operations.png" file_exists "${REPO_ROOT}/docs/screenshots/merchant_operations.png"
check 27 "Screenshot: feature_store_health.png" file_exists "${REPO_ROOT}/docs/screenshots/feature_store_health.png"
check 28 "Screenshot: feature_drift_monitor.png" file_exists "${REPO_ROOT}/docs/screenshots/feature_drift_monitor.png"
check 29 "Screenshot: pipeline_slos.png" file_exists "${REPO_ROOT}/docs/screenshots/pipeline_slos.png"
check 30 "Screenshot: finops.png" file_exists "${REPO_ROOT}/docs/screenshots/finops.png"

# --- Scripts ---
echo "--- Scripts ---"
check 31 "verify_phase6.sh exists" file_exists "${REPO_ROOT}/scripts/verify_phase6.sh"
check 32 "preflight.sh exists" file_exists "${REPO_ROOT}/scripts/preflight.sh"
check 33 "verify_clean.sh exists" file_exists "${REPO_ROOT}/scripts/verify_clean.sh"
check 34 "record_demo.md exists" file_exists "${REPO_ROOT}/scripts/record_demo.md"

# --- Summary ---
echo ""
echo "=== Phase 6 Verification Summary ==="
echo "  Passed: ${PASS}/${TOTAL}"
echo "  Failed: ${FAIL}/${TOTAL}"

if [[ ${FAIL} -eq 0 ]]; then
  echo "  STATUS: ALL CHECKS PASSED"
  exit 0
else
  echo "  STATUS: ${FAIL} CHECK(S) FAILED"
  exit 1
fi
