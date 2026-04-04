-- 19_mv_merchants.sql
-- Materialized View: streams from Kafka Engine to raw MergeTree storage.
-- Type conversions:
--   commission_rate (String) -> toDecimal64(commission_rate, 4)
--   credit_limit (String) -> toDecimal64(credit_limit, 2)
--   created_at, updated_at (Int64 epoch micros) -> fromUnixTimestamp64Micro

CREATE MATERIALIZED VIEW IF NOT EXISTS bronze.mv_pg_merchants
TO bronze.pg_merchants_raw
AS SELECT
    merchant_id,
    merchant_name,
    merchant_category,
    risk_tier,
    toDecimal64(commission_rate, 4)      AS commission_rate,
    toDecimal64(credit_limit, 2)         AS credit_limit,
    country,
    toDateTime64(fromUnixTimestamp64Micro(created_at), 3)  AS created_at,
    toDateTime64(fromUnixTimestamp64Micro(updated_at), 3)  AS updated_at,
    __op,
    __source_ts_ms
FROM bronze.pg_merchants_kafka;
