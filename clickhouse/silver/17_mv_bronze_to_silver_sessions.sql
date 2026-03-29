-- MV: bronze.mongo_merchant_sessions_raw → silver.merchant_sessions_silver
-- Includes created_at > '2000-01-01' filter (Phase 1 Deviation 10)
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_bronze_to_silver_sessions
TO silver.merchant_sessions_silver AS
SELECT
    session_id,
    toInt32OrZero(merchant_id) AS merchant_id,
    action,
    page,
    duration_seconds,
    created_at
FROM bronze.mongo_merchant_sessions_raw
WHERE created_at > '2000-01-01';
