-- MV: bronze.pg_transactions_raw → silver.transactions_silver
-- Filters out deletes (__op != 'd'), explicit column list
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_bronze_to_silver_tx
TO silver.transactions_silver AS
SELECT
    transaction_id,
    user_id,
    merchant_id,
    amount,
    currency,
    status,
    decision_latency_ms,
    installment_count,
    created_at
FROM bronze.pg_transactions_raw
WHERE __op != 'd';
