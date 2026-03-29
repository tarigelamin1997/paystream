-- 11_pg_users_raw.sql
-- Persistent MergeTree storage for users CDC events.
-- ReplacingMergeTree deduplicates by user_id using __source_ts_ms as version.
-- national_id contains masked data (asterisks) from Debezium MaskField SMT.

CREATE TABLE IF NOT EXISTS bronze.pg_users_raw
(
    user_id             Int64,
    full_name           String,
    email               String,
    phone               Nullable(String),
    national_id         Nullable(String),
    credit_limit        Decimal64(2),
    credit_tier         String,
    kyc_status          String,
    created_at          DateTime64(3),
    updated_at          DateTime64(3),
    __op                String,
    __source_ts_ms      Int64,
    _ingested_at        DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(__source_ts_ms)
ORDER BY (user_id)
PARTITION BY toYYYYMM(created_at);
