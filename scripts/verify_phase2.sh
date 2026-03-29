#!/bin/bash
set -euo pipefail
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"
CH="clickhouse-client --host ${CLICKHOUSE_HOST} --port ${CLICKHOUSE_PORT}"

PASSED=0
FAILED=0

check() {
  local num="$1" desc="$2" result="$3"
  if [[ "${result}" == "PASS" ]]; then
    echo "  CHECK ${num}: PASS — ${desc}"
    PASSED=$((PASSED + 1))
  else
    echo "  CHECK ${num}: FAIL — ${desc} (${result})"
    FAILED=$((FAILED + 1))
  fi
}

echo "=== PayStream Phase 2 Verification ==="

# Check 1: transactions_silver >= 400,000
TX=$($CH --query "SELECT count() FROM silver.transactions_silver")
[[ "$TX" -ge 400000 ]] && check 1 "transactions_silver >= 400K" "PASS" || check 1 "transactions_silver >= 400K" "count=${TX}"

# Check 2: repayments_silver >= 250,000
RP=$($CH --query "SELECT count() FROM silver.repayments_silver")
[[ "$RP" -ge 250000 ]] && check 2 "repayments_silver >= 250K" "PASS" || check 2 "repayments_silver >= 250K" "count=${RP}"

# Check 3: users_silver >= 50,000 (after FINAL)
US=$($CH --query "SELECT count() FROM silver.users_silver FINAL")
[[ "$US" -ge 50000 ]] && check 3 "users_silver >= 50K (FINAL)" "PASS" || check 3 "users_silver >= 50K (FINAL)" "count=${US}"

# Check 4: merchants_silver >= 200 (after FINAL)
MS=$($CH --query "SELECT count() FROM silver.merchants_silver FINAL")
[[ "$MS" -ge 200 ]] && check 4 "merchants_silver >= 200 (FINAL)" "PASS" || check 4 "merchants_silver >= 200 (FINAL)" "count=${MS}"

# Check 5: user_active_credit returns rows via sumMerge
UAC=$($CH --query "SELECT count() FROM (SELECT user_id, sumMerge(active_exposure) AS exp FROM silver.user_active_credit GROUP BY user_id)")
[[ "$UAC" -gt 0 ]] && check 5 "user_active_credit has rows (sumMerge)" "PASS" || check 5 "user_active_credit has rows" "count=${UAC}"

# Check 6: app_events_silver >= 800,000
AE=$($CH --query "SELECT count() FROM silver.app_events_silver")
[[ "$AE" -ge 800000 ]] && check 6 "app_events_silver >= 800K" "PASS" || check 6 "app_events_silver >= 800K" "count=${AE}"

# Check 7: delete_audit_log exists
DAL=$($CH --query "SELECT count() FROM system.tables WHERE database='silver' AND name='delete_audit_log'" 2>/dev/null)
[[ "$DAL" -ge 1 ]] && check 7 "delete_audit_log exists" "PASS" || check 7 "delete_audit_log exists" "missing"

# Check 8: merchant_daily_kpis has Projection
PROJ=$($CH --query "SELECT count() FROM system.projections WHERE database='gold' AND table='merchant_daily_kpis'" 2>/dev/null || echo "0")
[[ "$PROJ" -ge 1 ]] && check 8 "merchant_daily_kpis has Projection" "PASS" || check 8 "merchant_daily_kpis has Projection" "count=${PROJ}"

# Check 9: feature_store.user_credit_features exists with 14 columns
FS_COLS=$($CH --query "SELECT count() FROM system.columns WHERE database='feature_store' AND table='user_credit_features'" 2>/dev/null)
[[ "$FS_COLS" -ge 13 ]] && check 9 "user_credit_features has >= 13 columns" "PASS" || check 9 "user_credit_features columns" "count=${FS_COLS}"

# Check 10: amount type is Decimal (not Float)
AMT_TYPE=$($CH --query "SELECT type FROM system.columns WHERE database='silver' AND table='transactions_silver' AND name='amount'" 2>/dev/null)
[[ "$AMT_TYPE" == *"Decimal"* ]] && check 10 "amount is Decimal type" "PASS" || check 10 "amount type" "${AMT_TYPE}"

# Check 11: Bronze untouched
BRONZE_TX=$($CH --query "SELECT count() FROM bronze.pg_transactions_raw")
[[ "$BRONZE_TX" -ge 400000 ]] && check 11 "Bronze pg_transactions_raw untouched" "PASS" || check 11 "Bronze untouched" "count=${BRONZE_TX}"

# Check 12: EXPLAIN shows Projection
EXPLAIN_OUT=$($CH --query "EXPLAIN SELECT merchant_category, toMonth(date) AS month, sum(gmv), sum(transaction_count) FROM gold.merchant_daily_kpis GROUP BY merchant_category, month" 2>/dev/null)
if echo "$EXPLAIN_OUT" | grep -qi "projection\|proj_by_category"; then
  check 12 "EXPLAIN shows Projection" "PASS"
else
  check 12 "EXPLAIN shows Projection" "not found in EXPLAIN"
fi

echo ""
echo "=== Results: ${PASSED}/12 passed, ${FAILED}/12 failed ==="
[[ "${FAILED}" -gt 0 ]] && exit 1
echo "Phase 2 verification PASSED."
