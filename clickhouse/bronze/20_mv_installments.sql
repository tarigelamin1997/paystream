-- 20_mv_installments.sql
-- Materialized View: streams from Kafka Engine to raw MergeTree storage.
-- Type conversions:
--   total_amount, installment_amount (String) -> toDecimal64(..., 2)
--   start_date, end_date (String) -> toDate(...)
--   created_at (Int64 epoch micros) -> fromUnixTimestamp64Micro

CREATE MATERIALIZED VIEW IF NOT EXISTS bronze.mv_pg_installments
TO bronze.pg_installments_raw
AS SELECT
    schedule_id,
    transaction_id,
    user_id,
    toDecimal64(total_amount, 2)         AS total_amount,
    installment_count,
    toDecimal64(installment_amount, 2)   AS installment_amount,
    toDate(start_date)                   AS start_date,
    toDate(end_date)                     AS end_date,
    status,
    toDateTime64(fromUnixTimestamp64Micro(created_at), 3)  AS created_at,
    __op,
    __source_ts_ms
FROM bronze.pg_installments_kafka;
