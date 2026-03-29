-- Gold: dbt_test_results
-- Engine: MergeTree — Phase 5 data_quality_gate DAG writes test results here
CREATE TABLE IF NOT EXISTS gold.dbt_test_results (
    test_name            String,
    status               LowCardinality(String),
    execution_time       Float32,
    tested_at            DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(tested_at)
ORDER BY (tested_at, test_name);
