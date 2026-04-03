
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- Contract: silver.users_silver must have required columns for Gold models
-- Enforces contracts/silver_to_gold.yml


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
    ) dbt_internal_test