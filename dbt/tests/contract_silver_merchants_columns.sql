-- Contract: silver.merchants_silver must have required columns for Gold models
-- Enforces contracts/silver_to_gold.yml
{{ config(severity='error') }}

SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'silver'
      AND table = 'merchants_silver'
      AND name IN (
        'merchant_id', 'merchant_name', 'merchant_category', 'risk_tier',
        'commission_rate', 'credit_limit', 'created_at', '_ingested_at'
      )
) < 8
