#!/bin/bash
set -euo pipefail
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"
CH="clickhouse-client --host ${CLICKHOUSE_HOST} --port ${CLICKHOUSE_PORT}"
REGION="${AWS_REGION:-eu-north-1}"

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

echo "=== PayStream Phase 4 Verification ==="

# Check 1: count >= 40,000
FC=$($CH --query "SELECT count() FROM feature_store.user_credit_features")
[[ "$FC" -ge 40000 ]] && check 1 "feature_store count >= 40K" "PASS" || check 1 "feature_store count" "count=${FC}"

# Check 2: No NULLs in feature columns
NULL_COUNT=$($CH --query "SELECT count() FROM feature_store.user_credit_features WHERE tx_velocity_7d IS NULL OR tx_velocity_30d IS NULL OR avg_tx_amount_30d IS NULL OR repayment_rate_90d IS NULL OR merchant_diversity_30d IS NULL OR declined_rate_7d IS NULL OR active_installments IS NULL OR days_since_first_tx IS NULL")
[[ "$NULL_COUNT" -eq 0 ]] && check 2 "No NULLs in features" "PASS" || check 2 "NULLs found" "count=${NULL_COUNT}"

# Check 3: valid_to > valid_from
BAD_VALID=$($CH --query "SELECT count() FROM feature_store.user_credit_features WHERE valid_to <= valid_from")
[[ "$BAD_VALID" -eq 0 ]] && check 3 "valid_to > valid_from" "PASS" || check 3 "bad validity" "count=${BAD_VALID}"

# Check 4: feature_version = v2.1.0
WRONG_VER=$($CH --query "SELECT count() FROM feature_store.user_credit_features WHERE feature_version != 'v2.1.0'")
[[ "$WRONG_VER" -eq 0 ]] && check 4 "feature_version = v2.1.0" "PASS" || check 4 "wrong version" "count=${WRONG_VER}"

# Check 5: Point-in-time query returns 1 row
SAMPLE_USER=$($CH --query "SELECT user_id FROM feature_store.user_credit_features LIMIT 1")
SNAPSHOT_TS=$($CH --query "SELECT valid_from FROM feature_store.user_credit_features WHERE user_id = ${SAMPLE_USER} LIMIT 1")
PIT_COUNT=$($CH --query "SELECT count() FROM feature_store.user_credit_features WHERE user_id = ${SAMPLE_USER} AND valid_from <= '${SNAPSHOT_TS}' AND valid_to > '${SNAPSHOT_TS}'")
[[ "$PIT_COUNT" -eq 1 ]] && check 5 "Point-in-time query returns 1 row" "PASS" || check 5 "PIT query" "count=${PIT_COUNT}"

# Check 6: Delta Lake exists on S3
DELTA_EXISTS=$(aws s3 ls "s3://paystream-features-dev/user_credit/_delta_log/" --region "$REGION" 2>/dev/null | wc -l)
[[ "$DELTA_EXISTS" -gt 0 ]] && check 6 "Delta Lake _delta_log exists" "PASS" || check 6 "Delta Lake" "not found"

# Check 7: avg_tx_amount_30d is Decimal
AMT_TYPE=$($CH --query "SELECT toTypeName(avg_tx_amount_30d) FROM feature_store.user_credit_features LIMIT 1")
echo "$AMT_TYPE" | grep -qi "decimal" && check 7 "avg_tx_amount_30d is Decimal" "PASS" || check 7 "type" "${AMT_TYPE}"

# Check 8: repayment_rate in [0,1]
BAD_RATE=$($CH --query "SELECT count() FROM feature_store.user_credit_features WHERE repayment_rate_90d < 0 OR repayment_rate_90d > 1")
[[ "$BAD_RATE" -eq 0 ]] && check 8 "repayment_rate in [0,1]" "PASS" || check 8 "bad rates" "count=${BAD_RATE}"

# Check 9: tx_velocity_30d >= tx_velocity_7d
BAD_VEL=$($CH --query "SELECT count() FROM feature_store.user_credit_features WHERE tx_velocity_30d < tx_velocity_7d")
[[ "$BAD_VEL" -eq 0 ]] && check 9 "30d velocity >= 7d velocity" "PASS" || check 9 "velocity violation" "count=${BAD_VEL}"

# Check 10: Silver untouched
STX=$($CH --query "SELECT count() FROM silver.transactions_silver")
[[ "$STX" -ge 400000 ]] && check 10 "Silver untouched" "PASS" || check 10 "Silver" "count=${STX}"

# Check 11: Gold untouched
GLD=$($CH --query "SELECT count() FROM gold.merchant_daily_kpis")
[[ "$GLD" -gt 0 ]] && check 11 "Gold untouched" "PASS" || check 11 "Gold" "count=${GLD}"

# Check 12: No duplicate (user_id, valid_from)
TOTAL=$($CH --query "SELECT count() FROM feature_store.user_credit_features")
DISTINCT=$($CH --query "SELECT count() FROM (SELECT DISTINCT user_id, valid_from FROM feature_store.user_credit_features)")
[[ "$TOTAL" -eq "$DISTINCT" ]] && check 12 "No duplicate (user_id, valid_from)" "PASS" || check 12 "duplicates" "total=${TOTAL},distinct=${DISTINCT}"

echo ""
echo "=== Results: ${PASSED}/12 passed, ${FAILED}/12 failed ==="
[[ "${FAILED}" -gt 0 ]] && exit 1
echo "Phase 4 verification PASSED."
