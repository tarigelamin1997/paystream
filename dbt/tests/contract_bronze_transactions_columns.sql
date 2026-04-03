-- Contract: bronze.pg_transactions_raw must have required columns
-- Enforces contracts/bronze_to_silver.yml
{{ config(severity='error') }}

SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'bronze'
      AND table = 'pg_transactions_raw'
      AND name IN (
        'transaction_id', 'user_id', 'merchant_id', 'amount',
        'currency', 'status', 'decision_latency_ms', 'installment_count',
        'created_at', '_ingested_at'
      )
) < 10
