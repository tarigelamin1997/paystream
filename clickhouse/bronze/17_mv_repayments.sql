-- 17_mv_repayments.sql
-- Materialized View: streams from Kafka Engine to raw MergeTree storage.
-- Type conversions:
--   amount (String) -> toDecimal64(amount, 2)
--   due_date (String) -> toDate(due_date)
--   paid_at (Nullable Int64 epoch micros) -> fromUnixTimestamp64Micro (with NULL guard)
--   created_at, updated_at (Int64 epoch micros) -> fromUnixTimestamp64Micro

CREATE MATERIALIZED VIEW IF NOT EXISTS bronze.mv_pg_repayments
TO bronze.pg_repayments_raw
AS SELECT
    repayment_id,
    transaction_id,
    user_id,
    installment_number,
    toDecimal64(amount, 2)              AS amount,
    toDate(due_date)                    AS due_date,
    if(paid_at IS NOT NULL, toDateTime64(fromUnixTimestamp64Micro(paid_at), 3), NULL) AS paid_at,
    status,
    toDateTime64(fromUnixTimestamp64Micro(created_at), 3) AS created_at,
    toDateTime64(fromUnixTimestamp64Micro(updated_at), 3) AS updated_at,
    __op,
    __source_ts_ms
FROM bronze.pg_repayments_kafka;
