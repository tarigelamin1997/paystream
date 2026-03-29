-- 10_pg_repayments_raw.sql
-- Persistent MergeTree storage for repayments CDC events.
-- ReplacingMergeTree deduplicates by repayment_id using __source_ts_ms as version.

CREATE TABLE IF NOT EXISTS bronze.pg_repayments_raw
(
    repayment_id        Int64,
    transaction_id      Int64,
    user_id             Int64,
    installment_number  Int16,
    amount              Decimal64(2),
    due_date            Date,
    paid_at             Nullable(DateTime64(3)),
    status              String,
    created_at          DateTime64(3),
    updated_at          DateTime64(3),
    __op                String,
    __source_ts_ms      Int64,
    _ingested_at        DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(__source_ts_ms)
ORDER BY (repayment_id)
PARTITION BY toYYYYMM(created_at);
