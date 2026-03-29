-- Silver: merchant_sessions_silver
-- Engine: MergeTree — immutable portal events
CREATE TABLE IF NOT EXISTS silver.merchant_sessions_silver (
    session_id           String,
    merchant_id          Int32,
    action               LowCardinality(String),
    page                 String,
    duration_seconds     Int32,
    created_at           DateTime64(3),
    _ingested_at         DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(created_at)
ORDER BY (merchant_id, created_at)
TTL created_at + INTERVAL 1 YEAR;
