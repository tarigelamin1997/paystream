-- Contract: silver.users_silver must have required columns for Gold models
-- Enforces contracts/silver_to_gold.yml
{{ config(severity='error') }}

SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'silver'
      AND table = 'users_silver'
      AND name IN (
        'user_id', 'email', 'credit_limit', 'credit_tier',
        'kyc_status', 'created_at', 'updated_at', '_ingested_at'
      )
) < 8
