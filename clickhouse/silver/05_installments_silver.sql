-- Silver: installments_silver
-- Engine: MergeTree — schedule facts are immutable once created
CREATE TABLE IF NOT EXISTS silver.installments_silver (
    schedule_id          Int64,
    transaction_id       Int64,
    user_id              Int64,
    total_amount         Decimal(12, 2),
    installment_count    Int16,
    installment_amount   Decimal(12, 2),
    start_date           Date,
    end_date             Date,
    status               LowCardinality(String),
    created_at           DateTime64(3),
    _ingested_at         DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(start_date)
ORDER BY (user_id, transaction_id, schedule_id)
TTL start_date + INTERVAL 3 YEAR;
