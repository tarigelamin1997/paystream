-- 15_mongo_merchant_sessions_raw.sql
-- Persistent MergeTree storage for MongoDB merchant_sessions.
-- Plain MergeTree (not Replacing) because MongoDB events are immutable (insert-only).
-- Ordered by (action, created_at) for efficient filtering by action type.

CREATE TABLE IF NOT EXISTS bronze.mongo_merchant_sessions_raw
(
    session_id          String,
    merchant_id         String,
    action              String,
    page                Nullable(String),
    duration_seconds    Nullable(Int32),
    created_at          DateTime64(3),
    _ingested_at        DateTime DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (action, created_at)
PARTITION BY toYYYYMM(created_at);
