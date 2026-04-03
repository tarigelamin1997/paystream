
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- Contract: bronze.pg_merchants_raw must have required columns
-- Enforces contracts/bronze_to_silver.yml


SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'bronze'
      AND table = 'pg_merchants_raw'
      AND name IN (
        'merchant_id', 'merchant_name', 'merchant_category', 'risk_tier',
        'commission_rate', 'credit_limit', 'country', 'created_at',
        'updated_at', '_ingested_at'
      )
) < 10
    ) dbt_internal_test