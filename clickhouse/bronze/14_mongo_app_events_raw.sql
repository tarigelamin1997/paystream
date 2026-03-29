-- 14_mongo_app_events_raw.sql
-- Persistent MergeTree storage for MongoDB app_events.
-- Plain MergeTree (not Replacing) because MongoDB events are immutable (insert-only).
-- Ordered by (event_type, created_at) for efficient filtering by event type.

CREATE TABLE IF NOT EXISTS bronze.mongo_app_events_raw
(
    event_id    String,
    user_id     String,
    event_type  String,
    merchant_id Nullable(String),
    session_id  String,
    device_type String,
    event_data  String,
    created_at  DateTime64(3),
    _ingested_at DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (event_type, created_at)
PARTITION BY toYYYYMM(created_at);
