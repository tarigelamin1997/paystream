-- Gold: settlement_reconciliation
-- Engine: MergeTree — daily settlement facts
-- Populated by Phase 3 dbt
CREATE TABLE IF NOT EXISTS gold.settlement_reconciliation (
    settlement_date    Date,
    merchant_id        Int32,
    expected_amount    Decimal(15, 2),
    actual_amount      Decimal(15, 2),
    variance           Decimal(15, 2),
    variance_pct       Float32,
    status             LowCardinality(String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(settlement_date)
ORDER BY (settlement_date, merchant_id);
