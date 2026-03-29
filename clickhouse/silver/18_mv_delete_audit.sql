-- Delete Audit MVs — route __op='d' events from ALL Bronze PG tables to delete_audit_log
-- Deletes in BNPL are suspicious and require investigation

CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_delete_audit_tx
TO silver.delete_audit_log AS
SELECT
    'pg_transactions' AS source_table,
    toString(transaction_id) AS record_id,
    created_at AS deleted_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_transactions_raw
WHERE __op = 'd';

CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_delete_audit_repay
TO silver.delete_audit_log AS
SELECT
    'pg_repayments' AS source_table,
    toString(repayment_id) AS record_id,
    created_at AS deleted_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_repayments_raw
WHERE __op = 'd';

CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_delete_audit_users
TO silver.delete_audit_log AS
SELECT
    'pg_users' AS source_table,
    toString(user_id) AS record_id,
    created_at AS deleted_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_users_raw
WHERE __op = 'd';

CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_delete_audit_merchants
TO silver.delete_audit_log AS
SELECT
    'pg_merchants' AS source_table,
    toString(merchant_id) AS record_id,
    created_at AS deleted_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_merchants_raw
WHERE __op = 'd';

CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_delete_audit_installments
TO silver.delete_audit_log AS
SELECT
    'pg_installments' AS source_table,
    toString(schedule_id) AS record_id,
    created_at AS deleted_at,
    fromUnixTimestamp64Milli(__source_ts_ms) AS __source_ts_ms,
    '' AS raw_payload
FROM bronze.pg_installments_raw
WHERE __op = 'd';
