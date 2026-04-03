-- Contract: bronze.pg_repayments_raw must have required columns
-- Enforces contracts/bronze_to_silver.yml


SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'bronze'
      AND table = 'pg_repayments_raw'
      AND name IN (
        'repayment_id', 'transaction_id', 'user_id', 'installment_number',
        'amount', 'due_date', 'status', 'created_at',
        'updated_at', '_ingested_at'
      )
) < 10