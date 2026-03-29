-- 13_pg_installments_raw.sql
-- Persistent MergeTree storage for installments CDC events.
-- ReplacingMergeTree deduplicates by schedule_id using __source_ts_ms as version.

CREATE TABLE IF NOT EXISTS bronze.pg_installments_raw
(
    schedule_id         Int64,
    transaction_id      Int64,
    user_id             Int64,
    total_amount        Decimal64(2),
    installment_count   Int16,
    installment_amount  Decimal64(2),
    start_date          Date,
    end_date            Date,
    status              String,
    created_at          DateTime64(3),
    __op                String,
    __source_ts_ms      Int64,
    _ingested_at        DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(__source_ts_ms)
ORDER BY (schedule_id)
PARTITION BY toYYYYMM(created_at);
