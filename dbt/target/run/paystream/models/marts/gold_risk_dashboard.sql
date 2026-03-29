
        
  
    
    
    
        
        insert into `gold`.`risk_dashboard__dbt_tmp`
        ("date", "approval_rate", "decline_rate", "avg_decision_latency_ms", "fraud_flag_count", "total_exposure", "overdue_rate")

WITH  __dbt__cte__stg_transactions as (
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
), daily_metrics AS (
    SELECT
        toDate(created_at) AS date,
        countIf(status = 'approved') / count() AS approval_rate,
        countIf(status = 'declined') / count() AS decline_rate,
        avg(decision_latency_ms) AS avg_decision_latency_ms,
        toUInt32(0) AS fraud_flag_count,
        sumIf(amount, status = 'approved') AS total_exposure
    FROM `__dbt__cte__stg_transactions`
    GROUP BY toDate(created_at)
),
overdue AS (
    SELECT
        due_date AS date,
        countIf(status = 'overdue') / count() AS overdue_rate
    FROM `__dbt__cte__stg_repayments`
    GROUP BY due_date
)
SELECT
    dm.date,
    dm.approval_rate,
    dm.decline_rate,
    dm.avg_decision_latency_ms,
    dm.fraud_flag_count,
    dm.total_exposure,
    coalesce(o.overdue_rate, 0) AS overdue_rate
FROM daily_metrics dm
LEFT JOIN overdue o ON dm.date = o.date

  
    