-- Feature Store: user_credit_features
-- Engine: ReplacingMergeTree(snapshot_ts) — handles Spark re-runs and backfills
-- EMPTY until Phase 4 Spark populates it
-- ORDER BY (user_id, valid_from) matches Phase 4 write key
CREATE TABLE IF NOT EXISTS feature_store.user_credit_features (
    user_id                  Int64,
    snapshot_ts              DateTime64(3),
    valid_from               DateTime64(3),
    valid_to                 DateTime64(3),
    feature_version          LowCardinality(String),
    tx_velocity_7d           UInt16,
    tx_velocity_30d          UInt16,
    avg_tx_amount_30d        Decimal(10, 2),
    repayment_rate_90d       Float32,
    merchant_diversity_30d   UInt8,
    declined_rate_7d         Float32,
    active_installments      UInt8,
    days_since_first_tx      UInt16,
    _ingested_at             DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(snapshot_ts)
PARTITION BY toYYYYMM(valid_from)
ORDER BY (user_id, valid_from)
TTL valid_from + INTERVAL 2 YEAR;
