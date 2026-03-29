-- Gold: merchant_daily_kpis
-- Engine: SummingMergeTree — auto-sums numeric columns on merge
-- Projection: category rollups for dashboard queries
-- Populated by Phase 3 dbt, NOT by MVs (requires joins)
CREATE TABLE IF NOT EXISTS gold.merchant_daily_kpis (
    merchant_id        Int32,
    merchant_category  LowCardinality(String),
    date               Date,
    gmv                Decimal(15, 2),
    transaction_count  UInt32,
    approved_count     UInt32,
    declined_count     UInt32,
    approval_rate      Float32,
    avg_basket_size    Decimal(10, 2),
    bnpl_penetration   Float32
) ENGINE = SummingMergeTree((gmv, transaction_count, approved_count, declined_count))
PARTITION BY toYYYYMM(date)
ORDER BY (merchant_id, date);

ALTER TABLE gold.merchant_daily_kpis ADD PROJECTION IF NOT EXISTS proj_by_category (
    SELECT
        merchant_category,
        toMonth(date) AS month,
        sum(gmv) AS category_gmv,
        sum(transaction_count) AS category_tx_count
    GROUP BY merchant_category, month
);
