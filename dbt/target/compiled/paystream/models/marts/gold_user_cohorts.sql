

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
) SELECT
    toStartOfMonth(min(created_at)) AS cohort_month,
    user_id,
    sum(amount) AS ltv,
    toUInt32(count()) AS total_transactions,
    toDecimal64(0, 2) AS total_repaid,
    toUInt8(dateDiff('month', min(created_at), max(created_at))) AS retention_months,
    if(count() > 1, toFloat32((count() - 1)) / toFloat32(count()), toFloat32(0)) AS reorder_rate
FROM `__dbt__cte__stg_transactions`
GROUP BY user_id

HAVING toStartOfMonth(min(created_at)) >= (SELECT max(cohort_month) - INTERVAL 3 MONTH FROM `gold`.`user_cohorts`)
