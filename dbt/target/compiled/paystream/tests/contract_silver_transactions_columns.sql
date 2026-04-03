-- Contract: silver.transactions_silver must have required columns for Gold models
-- Enforces contracts/silver_to_gold.yml


SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'silver'
      AND table = 'transactions_silver'
      AND name IN (
        'transaction_id', 'user_id', 'merchant_id', 'amount',
        'currency', 'status', 'decision_latency_ms', 'installment_count',
        'created_at', '_ingested_at'
      )
) < 10