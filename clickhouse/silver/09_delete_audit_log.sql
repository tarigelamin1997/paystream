-- Silver: delete_audit_log
-- Engine: MergeTree — captures all __op='d' events for investigation
-- In BNPL, deletes are suspicious and require an audit trail
CREATE TABLE IF NOT EXISTS silver.delete_audit_log (
    source_table         LowCardinality(String),
    record_id            String,
    deleted_at           DateTime64(3),
    __source_ts_ms       DateTime64(3),
    raw_payload          String,
    _ingested_at         DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(deleted_at)
ORDER BY (source_table, record_id, deleted_at)
TTL deleted_at + INTERVAL 2 YEAR;
