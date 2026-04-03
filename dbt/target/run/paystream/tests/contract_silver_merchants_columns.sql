
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- Contract: silver.merchants_silver must have required columns for Gold models
-- Enforces contracts/silver_to_gold.yml


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
    ) dbt_internal_test