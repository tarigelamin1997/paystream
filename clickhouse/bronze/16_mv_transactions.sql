-- 16_mv_transactions.sql
-- Materialized View: streams from Kafka Engine to raw MergeTree storage.
-- Type conversions:
--   amount (String) -> toDecimal64(amount, 2)
--   created_at (Int64 epoch micros) -> fromUnixTimestamp64Micro(created_at)

CREATE MATERIALIZED VIEW IF NOT EXISTS bronze.mv_pg_transactions
TO bronze.pg_transactions_raw
AS SELECT
    transaction_id,
    user_id,
    merchant_id,
    toDecimal64(amount, 2)          AS amount,
    currency,
    status,
    decision_latency_ms,
    installment_count,
    toDateTime64(fromUnixTimestamp64Micro(created_at), 3) AS created_at,
    __op,
    __source_ts_ms
FROM bronze.pg_transactions_kafka;
