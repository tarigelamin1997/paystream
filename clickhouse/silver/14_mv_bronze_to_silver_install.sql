-- MV: bronze.pg_installments_raw → silver.installments_silver
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_bronze_to_silver_install
TO silver.installments_silver AS
SELECT
    schedule_id,
    transaction_id,
    user_id,
    total_amount,
    installment_count,
    installment_amount,
    start_date,
    end_date,
    status,
    created_at
FROM bronze.pg_installments_raw
WHERE __op != 'd';
