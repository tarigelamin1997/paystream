-- Gold: user_cohorts
-- Engine: SummingMergeTree — auto-sums LTV, transaction counts, repaid amounts
-- Populated by Phase 3 dbt
CREATE TABLE IF NOT EXISTS gold.user_cohorts (
    cohort_month       Date,
    user_id            Int64,
    ltv                Decimal(12, 2),
    total_transactions UInt32,
    total_repaid       Decimal(12, 2),
    retention_months   UInt8,
    reorder_rate       Float32
) ENGINE = SummingMergeTree((ltv, total_transactions, total_repaid))
PARTITION BY toYYYYMM(cohort_month)
ORDER BY (cohort_month, user_id);
