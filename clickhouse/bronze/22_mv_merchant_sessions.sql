-- 22_mv_merchant_sessions.sql
-- Materialized View: streams from Kafka Engine to raw MergeTree storage.
-- Type conversions:
--   created_at (ISO string from MongoDB) -> parseDateTimeBestEffort(created_at)

CREATE MATERIALIZED VIEW IF NOT EXISTS bronze.mv_mongo_merchant_sessions
TO bronze.mongo_merchant_sessions_raw
AS SELECT
    session_id,
    merchant_id,
    action,
    page,
    duration_seconds,
    parseDateTimeBestEffort(created_at) AS created_at
FROM bronze.mongo_merchant_sessions_kafka;
