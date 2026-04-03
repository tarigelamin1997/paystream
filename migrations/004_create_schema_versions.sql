-- Phase 7B: Schema versions tracking table
-- Records every DDL migration applied to ClickHouse
CREATE TABLE IF NOT EXISTS gold.schema_versions (
    version UInt32,
    description String,
    applied_at DateTime64(3) DEFAULT now64(3),
    checksum String,         -- MD5 of migration SQL file
    execution_time_ms UInt32
) ENGINE = MergeTree()
ORDER BY version;
