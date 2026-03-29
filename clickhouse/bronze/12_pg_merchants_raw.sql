-- 12_pg_merchants_raw.sql
-- Persistent MergeTree storage for merchants CDC events.
-- ReplacingMergeTree deduplicates by merchant_id using __source_ts_ms as version.
-- commission_rate uses Decimal64(4) for 4-decimal-place precision.

CREATE TABLE IF NOT EXISTS bronze.pg_merchants_raw
(
    merchant_id         Int32,
    merchant_name       String,
    merchant_category   String,
    risk_tier           String,
    commission_rate     Decimal64(4),
    credit_limit        Decimal64(2),
    country             String,
    created_at          DateTime64(3),
    updated_at          DateTime64(3),
    __op                String,
    __source_ts_ms      Int64,
    _ingested_at        DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(__source_ts_ms)
ORDER BY (merchant_id)
PARTITION BY toYYYYMM(created_at);
