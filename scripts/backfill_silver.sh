#!/bin/bash
set -euo pipefail
# Phase 2 — Backfill Silver tables from existing Bronze data
# MVs are forward-only — this one-time backfill populates Silver with seed data
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"
CH="clickhouse-client --host ${CLICKHOUSE_HOST} --port ${CLICKHOUSE_PORT}"

echo "=== Backfilling Silver from Bronze ==="

echo "[1/8] transactions_silver..."
$CH --query "INSERT INTO silver.transactions_silver
SELECT transaction_id, user_id, merchant_id, amount, currency, status,
       decision_latency_ms, installment_count, created_at
FROM bronze.pg_transactions_raw WHERE __op != 'd'"

echo "[2/8] repayments_silver..."
$CH --query "INSERT INTO silver.repayments_silver
SELECT repayment_id, transaction_id, user_id, installment_number, amount,
       due_date, paid_at, status, created_at, updated_at
FROM bronze.pg_repayments_raw WHERE __op != 'd'"

echo "[3/8] users_silver..."
$CH --query "INSERT INTO silver.users_silver
SELECT user_id, full_name, email, phone, national_id AS national_id_hash,
       credit_limit, credit_tier, kyc_status, created_at, updated_at,
       toUInt64(__source_ts_ms) AS _version
FROM bronze.pg_users_raw WHERE __op != 'd'"

echo "[4/8] merchants_silver..."
$CH --query "INSERT INTO silver.merchants_silver
SELECT merchant_id, merchant_name, merchant_category, risk_tier,
       commission_rate, credit_limit, country, created_at, updated_at,
       toUInt64(__source_ts_ms) AS _version
FROM bronze.pg_merchants_raw WHERE __op != 'd'"

echo "[5/8] installments_silver..."
$CH --query "INSERT INTO silver.installments_silver
SELECT schedule_id, transaction_id, user_id, total_amount, installment_count,
       installment_amount, start_date, end_date, status, created_at
FROM bronze.pg_installments_raw WHERE __op != 'd'"

echo "[6/8] user_active_credit (AggregatingMergeTree with sumState)..."
$CH --query "INSERT INTO silver.user_active_credit
SELECT user_id, sumState(amount) AS active_exposure
FROM bronze.pg_transactions_raw
WHERE __op != 'd' AND status = 'approved'
GROUP BY user_id"

echo "[7/8] app_events_silver (with zero-date filter)..."
$CH --query "INSERT INTO silver.app_events_silver
SELECT event_id, toInt64OrZero(user_id) AS user_id, event_type,
       if(merchant_id IS NOT NULL AND merchant_id != '', toNullable(toInt32OrZero(merchant_id)), NULL) AS merchant_id,
       session_id, device_type, event_data, created_at
FROM bronze.mongo_app_events_raw
WHERE created_at > '2000-01-01'"

echo "[8/8] merchant_sessions_silver (with zero-date filter)..."
$CH --query "INSERT INTO silver.merchant_sessions_silver
SELECT session_id, toInt32OrZero(merchant_id) AS merchant_id, action,
       page, duration_seconds, created_at
FROM bronze.mongo_merchant_sessions_raw
WHERE created_at > '2000-01-01'"

echo ""
echo "=== Backfill Complete ==="
echo "Silver row counts:"
for tbl in transactions_silver repayments_silver users_silver merchants_silver installments_silver app_events_silver merchant_sessions_silver; do
  count=$($CH --query "SELECT count() FROM silver.${tbl}")
  echo "  ${tbl}: ${count}"
done
echo "  user_active_credit users: $($CH --query "SELECT count() FROM silver.user_active_credit")"
