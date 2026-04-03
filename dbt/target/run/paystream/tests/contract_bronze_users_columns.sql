
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- Contract: bronze.pg_users_raw must have required columns
-- Enforces contracts/bronze_to_silver.yml


SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'bronze'
      AND table = 'pg_users_raw'
      AND name IN (
        'user_id', 'full_name', 'email', 'credit_limit',
        'credit_tier', 'kyc_status', 'created_at', 'updated_at',
        '_ingested_at'
      )
) < 9
    ) dbt_internal_test