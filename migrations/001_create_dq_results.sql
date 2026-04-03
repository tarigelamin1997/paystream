-- Phase 7A: Data Quality results table
-- Central store for all DQ checks across all pipeline stages
CREATE TABLE IF NOT EXISTS gold.dq_results (
    check_time DateTime64(3) DEFAULT now64(3),
    stage String,           -- 'bronze', 'silver', 'gold', 'feature_store', 'serving'
    check_name String,      -- 'null_check_transaction_id', 'freshness_pg_transactions', etc.
    check_type String,      -- 'freshness', 'null', 'unique', 'referential', 'range', 'completeness', 'contract'
    status String,          -- 'pass', 'warn', 'fail'
    details String,         -- JSON with specifics
    rows_checked UInt64,
    rows_failed UInt64
) ENGINE = MergeTree()
ORDER BY (stage, check_name, check_time)
TTL toDateTime(check_time) + INTERVAL 90 DAY;
