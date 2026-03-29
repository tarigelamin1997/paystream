-- Silver: app_events_silver
-- Engine: MergeTree — immutable behavioural events
-- event_data stored as String (raw JSON) for schema flexibility
CREATE TABLE IF NOT EXISTS silver.app_events_silver (
    event_id             String,
    user_id              Int64,
    event_type           LowCardinality(String),
    merchant_id          Nullable(Int32),
    session_id           String,
    device_type          LowCardinality(String),
    event_data           String,
    created_at           DateTime64(3),
    _ingested_at         DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(created_at)
ORDER BY (user_id, event_type, created_at)
TTL created_at + INTERVAL 2 YEAR;
