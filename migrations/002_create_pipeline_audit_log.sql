-- Phase 7B: Pipeline audit log table
-- Tracks every DAG run, task execution, and pipeline event
CREATE TABLE IF NOT EXISTS gold.pipeline_audit_log (
    event_time DateTime64(3) DEFAULT now64(3),
    dag_id String,
    task_id String,
    run_id String,
    status String,           -- 'started', 'success', 'failed', 'skipped'
    duration_seconds Float32,
    details String,          -- JSON: row counts, error messages, etc.
    _ingested_at DateTime64(3) DEFAULT now64(3)
) ENGINE = MergeTree()
ORDER BY (dag_id, task_id, event_time)
TTL toDateTime(event_time) + INTERVAL 90 DAY;
