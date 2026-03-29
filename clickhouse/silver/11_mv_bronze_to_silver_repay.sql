-- MV: bronze.pg_repayments_raw → silver.repayments_silver
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_bronze_to_silver_repay
TO silver.repayments_silver AS
SELECT
    repayment_id,
    transaction_id,
    user_id,
    installment_number,
    amount,
    due_date,
    paid_at,
    status,
    created_at,
    updated_at
FROM bronze.pg_repayments_raw
WHERE __op != 'd';
