-- MV: bronze.pg_users_raw → silver.users_silver
-- _version = __source_ts_ms for ReplacingMergeTree ordering
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_bronze_to_silver_users
TO silver.users_silver AS
SELECT
    user_id,
    full_name,
    email,
    phone,
    national_id AS national_id_hash,
    credit_limit,
    credit_tier,
    kyc_status,
    created_at,
    updated_at,
    toUInt64(__source_ts_ms) AS _version
FROM bronze.pg_users_raw
WHERE __op != 'd';
