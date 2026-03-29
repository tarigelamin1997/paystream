-- Silver: transactions_silver
-- Engine: MergeTree — immutable financial facts
-- Duplicate CDC events kept as bug evidence, not silently deduplicated
CREATE TABLE IF NOT EXISTS silver.transactions_silver (
    transaction_id       Int64,
    user_id              Int64,
    merchant_id          Int32,
    amount               Decimal(12, 2),
    currency             LowCardinality(String),
    status               LowCardinality(String),
    decision_latency_ms  Nullable(Int16),
    installment_count    Int16,
    created_at           DateTime64(3),
    _ingested_at         DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(created_at)
ORDER BY (merchant_id, user_id, created_at)
TTL created_at + INTERVAL 5 YEAR;
