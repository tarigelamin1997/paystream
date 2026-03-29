

  create view `silver`.`int_transaction_enriched__dbt_tmp` 
  
    
    
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
),  __dbt__cte__stg_users as (
-- Staging: users — FINAL for ReplacingMergeTree (latest state)
SELECT
    user_id,
    full_name,
    email,
    phone,
    national_id_hash,
    credit_limit,
    credit_tier,
    kyc_status,
    created_at,
    updated_at
FROM `silver`.`users_silver` FINAL
),  __dbt__cte__stg_merchants as (
-- Staging: merchants — FINAL for ReplacingMergeTree (latest state)
SELECT
    merchant_id,
    merchant_name,
    merchant_category,
    risk_tier,
    commission_rate,
    credit_limit,
    country,
    created_at,
    updated_at
FROM `silver`.`merchants_silver` FINAL
) -- Intermediate: transaction enriched with user and merchant dimensions
-- Materialized as view — avoids data duplication
SELECT
    t.transaction_id AS transaction_id,
    t.user_id AS user_id,
    t.merchant_id AS merchant_id,
    t.amount AS amount,
    t.currency AS currency,
    t.status AS status,
    t.decision_latency_ms AS decision_latency_ms,
    t.installment_count AS installment_count,
    t.created_at AS created_at,
    u.credit_tier AS user_credit_tier,
    u.credit_limit AS user_credit_limit,
    u.kyc_status AS user_kyc_status,
    m.merchant_name,
    m.merchant_category,
    m.risk_tier AS merchant_risk_tier,
    m.commission_rate AS merchant_commission_rate
FROM `__dbt__cte__stg_transactions` t
LEFT JOIN `__dbt__cte__stg_users` u ON t.user_id = u.user_id
LEFT JOIN `__dbt__cte__stg_merchants` m ON t.merchant_id = m.merchant_id
  )
      
      
                    -- end_of_sql
                    
                    