with __dbt__cte__stg_repayments as (
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
),  __dbt__cte__stg_transactions as (
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
) -- Intermediate: repayment timeline — installment lifecycle
SELECT
    r.repayment_id AS repayment_id,
    r.transaction_id AS transaction_id,
    r.user_id AS user_id,
    r.installment_number AS installment_number,
    r.amount AS repayment_amount,
    r.due_date AS due_date,
    r.paid_at AS paid_at,
    r.status AS repayment_status,
    r.created_at AS created_at,
    t.amount AS transaction_amount,
    t.status AS transaction_status,
    t.merchant_id AS merchant_id,
    dateDiff('day', r.due_date, coalesce(toDate(r.paid_at), today())) AS days_from_due
FROM `__dbt__cte__stg_repayments` r
LEFT JOIN `__dbt__cte__stg_transactions` t ON r.transaction_id = t.transaction_id