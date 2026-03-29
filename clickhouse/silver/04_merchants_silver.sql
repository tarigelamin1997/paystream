-- Silver: merchants_silver
-- Engine: ReplacingMergeTree(_version) — risk tier, commission rate changes
CREATE TABLE IF NOT EXISTS silver.merchants_silver (
    merchant_id          Int32,
    merchant_name        String,
    merchant_category    LowCardinality(String),
    risk_tier            LowCardinality(String),
    commission_rate      Decimal(5, 4),
    credit_limit         Decimal(15, 2),
    country              LowCardinality(String),
    created_at           DateTime64(3),
    updated_at           DateTime64(3),
    _version             UInt64,
    _ingested_at         DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(_version)
ORDER BY (merchant_id);
