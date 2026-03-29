-- Silver: users_silver
-- Engine: ReplacingMergeTree(_version) — profile updates (credit limit, KYC, phone)
CREATE TABLE IF NOT EXISTS silver.users_silver (
    user_id              Int64,
    full_name            String,
    email                String,
    phone                Nullable(String),
    national_id_hash     String,
    credit_limit         Decimal(12, 2),
    credit_tier          LowCardinality(String),
    kyc_status           LowCardinality(String),
    created_at           DateTime64(3),
    updated_at           DateTime64(3),
    _version             UInt64,
    _ingested_at         DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(_version)
ORDER BY (user_id);
