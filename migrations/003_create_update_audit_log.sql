-- Phase 7B: Update audit log table + MVs
-- Mirrors silver.delete_audit_log but captures __op = 'u' (update) events
-- See also: silver.delete_audit_log + mv_delete_audit_* (Phase 2)

CREATE TABLE IF NOT EXISTS silver.update_audit_log (
    source_table LowCardinality(String),
    record_id String,
    updated_at DateTime64(3),
    __source_ts_ms DateTime64(3),
    raw_payload String,
    _ingested_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (source_table, record_id, updated_at)
TTL _ingested_at + INTERVAL 90 DAY;

-- MV: pg_transactions_raw updates
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_update_audit_tx TO silver.update_audit_log (
    source_table String, record_id String, updated_at DateTime64(3),
    __source_ts_ms DateTime64(3), raw_payload String
) AS SELECT
    'pg_transactions' AS source_table,
    toString(transaction_id) AS record_id,
    created_at AS updated_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_transactions_raw
WHERE __op = 'u';

-- MV: pg_users_raw updates
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_update_audit_users TO silver.update_audit_log (
    source_table String, record_id String, updated_at DateTime64(3),
    __source_ts_ms DateTime64(3), raw_payload String
) AS SELECT
    'pg_users' AS source_table,
    toString(user_id) AS record_id,
    created_at AS updated_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_users_raw
WHERE __op = 'u';

-- MV: pg_merchants_raw updates
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_update_audit_merchants TO silver.update_audit_log (
    source_table String, record_id String, updated_at DateTime64(3),
    __source_ts_ms DateTime64(3), raw_payload String
) AS SELECT
    'pg_merchants' AS source_table,
    toString(merchant_id) AS record_id,
    created_at AS updated_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_merchants_raw
WHERE __op = 'u';

-- MV: pg_repayments_raw updates
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_update_audit_repay TO silver.update_audit_log (
    source_table String, record_id String, updated_at DateTime64(3),
    __source_ts_ms DateTime64(3), raw_payload String
) AS SELECT
    'pg_repayments' AS source_table,
    toString(repayment_id) AS record_id,
    created_at AS updated_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_repayments_raw
WHERE __op = 'u';

-- MV: pg_installments_raw updates
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_update_audit_installments TO silver.update_audit_log (
    source_table String, record_id String, updated_at DateTime64(3),
    __source_ts_ms DateTime64(3), raw_payload String
) AS SELECT
    'pg_installments' AS source_table,
    toString(schedule_id) AS record_id,
    created_at AS updated_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_installments_raw
WHERE __op = 'u';
