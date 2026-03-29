-- Gold: risk_dashboard
-- Engine: SummingMergeTree — auto-sums fraud flag counts
-- Populated by Phase 3 dbt
CREATE TABLE IF NOT EXISTS gold.risk_dashboard (
    date               Date,
    approval_rate      Float32,
    decline_rate       Float32,
    avg_decision_latency_ms Float32,
    fraud_flag_count   UInt32,
    total_exposure     Decimal(15, 2),
    overdue_rate       Float32
) ENGINE = SummingMergeTree((fraud_flag_count))
PARTITION BY toYYYYMM(date)
ORDER BY (date);
