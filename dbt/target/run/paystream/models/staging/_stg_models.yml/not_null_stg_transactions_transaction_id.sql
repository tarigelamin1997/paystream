
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



with __dbt__cte__stg_transactions as (
-- Staging: transactions
-- Ephemeral — filter cancelled, standardize
SELECT
    transaction_id,
    user_id,
    merchant_id,
    amount,
    currency,
    status,
    decision_latency_ms,
    installment_count,
    created_at
FROM `silver`.`transactions_silver`
WHERE status != 'cancelled'
) select transaction_id
from `__dbt__cte__stg_transactions`
where transaction_id is null



    ) dbt_internal_test