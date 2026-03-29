-- 09_pg_transactions_raw.sql
-- Persistent MergeTree storage for transactions CDC events.
-- ReplacingMergeTree deduplicates by transaction_id using __source_ts_ms as version.
-- Type conversions (String->Decimal, Int64->DateTime) happen in the MV, not here.

CREATE TABLE IF NOT EXISTS bronze.pg_transactions_raw
(
    transaction_id      Int64,
    user_id             Int64,
    merchant_id         Int32,
    amount              Decimal64(2),
    currency            String,
    status              String,
    decision_latency_ms Nullable(Int16),
    installment_count   Int16,
    created_at          DateTime64(3),
    __op                String,
    __source_ts_ms      Int64,
    _ingested_at        DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(__source_ts_ms)
ORDER BY (transaction_id)
PARTITION BY toYYYYMM(created_at);
