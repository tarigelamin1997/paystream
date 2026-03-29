-- 21_mv_app_events.sql
-- Materialized View: streams from Kafka Engine to raw MergeTree storage.
-- Type conversions:
--   created_at (ISO string from MongoDB) -> parseDateTimeBestEffort(created_at)

CREATE MATERIALIZED VIEW IF NOT EXISTS bronze.mv_mongo_app_events
TO bronze.mongo_app_events_raw
AS SELECT
    event_id,
    user_id,
    event_type,
    merchant_id,
    session_id,
    device_type,
    event_data,
    parseDateTimeBestEffort(created_at) AS created_at
FROM bronze.mongo_app_events_kafka;
