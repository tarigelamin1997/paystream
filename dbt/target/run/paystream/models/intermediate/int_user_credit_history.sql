

  create view `silver`.`int_user_credit_history__dbt_tmp` 
  
    
    
  as (
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
),  __dbt__cte__stg_repayments as (
-- Staging: repayments — FINAL for ReplacingMergeTree (latest state)
SELECT
    repayment_id,
    transaction_id,
    user_id,
    installment_number,
    amount,
    due_date,
    paid_at,
    lower(status) AS status,
    created_at,
    updated_at
FROM `silver`.`repayments_silver` FINAL
) -- Intermediate: user credit history — all transactions + repayments per user
-- Feeds Phase 4 Spark feature engineering
SELECT
    t.user_id AS user_id,
    t.transaction_id AS transaction_id,
    t.amount AS tx_amount,
    t.status AS tx_status,
    t.merchant_id AS merchant_id,
    t.created_at AS tx_date,
    r.repayment_id AS repayment_id,
    r.amount AS repayment_amount,
    r.status AS repayment_status,
    r.due_date AS due_date,
    r.paid_at AS paid_at
FROM `__dbt__cte__stg_transactions` t
LEFT JOIN `__dbt__cte__stg_repayments` r
    ON t.transaction_id = r.transaction_id
  )
      
      
                    -- end_of_sql
                    
                    