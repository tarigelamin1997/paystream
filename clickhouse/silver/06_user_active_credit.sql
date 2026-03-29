-- Silver: user_active_credit
-- Engine: AggregatingMergeTree — running sum of open exposure per user
-- NOT SummingMergeTree: cannot aggregate Decimal correctly across partial merge states
-- Read with: SELECT user_id, sumMerge(active_exposure) FROM silver.user_active_credit GROUP BY user_id
CREATE TABLE IF NOT EXISTS silver.user_active_credit (
    user_id              Int64,
    active_exposure      AggregateFunction(sum, Decimal(12, 2))
) ENGINE = AggregatingMergeTree()
ORDER BY (user_id);
