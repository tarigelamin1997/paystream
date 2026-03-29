-- 18_mv_users.sql
-- Materialized View: streams from Kafka Engine to raw MergeTree storage.
-- Type conversions:
--   credit_limit (String) -> toDecimal64(credit_limit, 2)
--   created_at, updated_at (Int64 epoch millis) -> fromUnixTimestamp64Milli

CREATE MATERIALIZED VIEW IF NOT EXISTS bronze.mv_pg_users
TO bronze.pg_users_raw
AS SELECT
    user_id,
    full_name,
    email,
    phone,
    national_id,
    toDecimal64(credit_limit, 2)         AS credit_limit,
    credit_tier,
    kyc_status,
    fromUnixTimestamp64Milli(created_at)  AS created_at,
    fromUnixTimestamp64Milli(updated_at)  AS updated_at,
    __op,
    __source_ts_ms
FROM bronze.pg_users_kafka;
