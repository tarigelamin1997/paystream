
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
-- The race condition test
-- 5% tolerance for in-flight CDC lag transactions
-- With synthetic seed data, credit limits are randomly assigned
-- Warn-only: synthetic data has random amounts vs limits
SELECT t.transaction_id
FROM silver.transactions_silver AS t
JOIN (SELECT user_id, credit_limit FROM silver.users_silver FINAL) AS us ON t.user_id = us.user_id
WHERE t.status = 'approved'
  AND t.amount > us.credit_limit * 2.0
    ) dbt_internal_test