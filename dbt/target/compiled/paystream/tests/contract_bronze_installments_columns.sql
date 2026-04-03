-- Contract: bronze.pg_installments_raw must have required columns
-- Enforces contracts/bronze_to_silver.yml


SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'bronze'
      AND table = 'pg_installments_raw'
      AND name IN (
        'schedule_id', 'transaction_id', 'user_id', 'total_amount',
        'installment_count', 'installment_amount', 'start_date', 'end_date',
        'status', 'created_at', '_ingested_at'
      )
) < 11