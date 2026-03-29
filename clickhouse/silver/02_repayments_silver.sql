-- Silver: repayments_silver
-- Engine: ReplacingMergeTree(updated_at) — status changes (pending → paid → overdue)
CREATE TABLE IF NOT EXISTS silver.repayments_silver (
    repayment_id         Int64,
    transaction_id       Int64,
    user_id              Int64,
    installment_number   Int16,
    amount               Decimal(12, 2),
    due_date             Date,
    paid_at              Nullable(DateTime64(3)),
    status               LowCardinality(String),
    created_at           DateTime64(3),
    updated_at           DateTime64(3),
    _ingested_at         DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMM(due_date)
ORDER BY (user_id, transaction_id, installment_number)
TTL due_date + INTERVAL 3 YEAR;
