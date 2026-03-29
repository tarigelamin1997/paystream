-- MV: bronze.mongo_app_events_raw → silver.app_events_silver
-- Includes created_at > '2000-01-01' filter for zero-date rows (Phase 1 Deviation 10)
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_bronze_to_silver_events
TO silver.app_events_silver AS
SELECT
    event_id,
    toInt64OrZero(user_id) AS user_id,
    event_type,
    if(merchant_id IS NOT NULL AND merchant_id != '', toNullable(toInt32OrZero(merchant_id)), NULL) AS merchant_id,
    session_id,
    device_type,
    event_data,
    created_at
FROM bronze.mongo_app_events_raw
WHERE created_at > '2000-01-01';
