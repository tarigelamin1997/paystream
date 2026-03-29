-- MV: bronze.pg_merchants_raw → silver.merchants_silver
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_bronze_to_silver_merchants
TO silver.merchants_silver AS
SELECT
    merchant_id,
    merchant_name,
    merchant_category,
    risk_tier,
    commission_rate,
    credit_limit,
    country,
    created_at,
    updated_at,
    toUInt64(__source_ts_ms) AS _version
FROM bronze.pg_merchants_raw
WHERE __op != 'd';
