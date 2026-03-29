-- Portfolio evidence: Projection scan reduction
-- This file documents the EXPLAIN output showing Projection usage
-- Run after inserting test data into gold.merchant_daily_kpis

-- Step 1: Insert sample data for EXPLAIN demonstration
INSERT INTO gold.merchant_daily_kpis VALUES
(1, 'electronics', '2024-01-15', 1500.00, 10, 8, 2, 0.80, 150.00, 0.65),
(2, 'fashion', '2024-01-15', 2500.00, 20, 18, 2, 0.90, 125.00, 0.70),
(1, 'electronics', '2024-02-15', 1800.00, 12, 10, 2, 0.83, 150.00, 0.68),
(2, 'fashion', '2024-02-15', 3000.00, 25, 22, 3, 0.88, 120.00, 0.72);

-- Step 2: Materialize the projection
OPTIMIZE TABLE gold.merchant_daily_kpis FINAL;

-- Step 3: EXPLAIN query that should use the Projection
-- Expected: ReadFromMergeTree shows proj_by_category usage
EXPLAIN
SELECT
    merchant_category,
    toMonth(date) AS month,
    sum(gmv) AS category_gmv,
    sum(transaction_count) AS category_tx_count
FROM gold.merchant_daily_kpis
GROUP BY merchant_category, month;
