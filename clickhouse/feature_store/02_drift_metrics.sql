-- Feature Store: drift_metrics
-- Stores IQR drift scores per feature, written by feature_drift_monitor DAG
-- Replaces AMP remote-write (snappy C-extension unavailable in MWAA)
CREATE TABLE IF NOT EXISTS feature_store.drift_metrics (
    feature_name     LowCardinality(String),
    drift_score      Float64,
    is_drifted       UInt8,
    baseline_median  Float64,
    current_median   Float64,
    measured_at      DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (feature_name, measured_at);
