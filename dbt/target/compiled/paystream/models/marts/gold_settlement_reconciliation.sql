

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
), daily_tx AS (
    SELECT
        toDate(created_at) AS settlement_date,
        merchant_id,
        sumIf(amount, status = 'approved') AS expected_amount
    FROM `__dbt__cte__stg_transactions`
    GROUP BY toDate(created_at), merchant_id
),
daily_repay AS (
    SELECT
        toDate(paid_at) AS settlement_date,
        merchant_id,
        sum(repayment_amount) AS actual_amount
    FROM `silver`.`int_repayment_timeline`
    WHERE repayment_status = 'paid' AND paid_at IS NOT NULL
    GROUP BY toDate(paid_at), merchant_id
)
SELECT
    dt.settlement_date,
    dt.merchant_id,
    coalesce(dt.expected_amount, toDecimal64(0, 2)) AS expected_amount,
    coalesce(dr.actual_amount, toDecimal64(0, 2)) AS actual_amount,
    coalesce(dt.expected_amount, toDecimal64(0, 2)) - coalesce(dr.actual_amount, toDecimal64(0, 2)) AS variance,
    if(dt.expected_amount > 0, (dt.expected_amount - coalesce(dr.actual_amount, toDecimal64(0, 2))) / dt.expected_amount, 0) AS variance_pct,
    multiIf(
        abs(coalesce(dt.expected_amount, toDecimal64(0, 2)) - coalesce(dr.actual_amount, toDecimal64(0, 2))) < 0.01, 'matched',
        dr.actual_amount IS NULL, 'pending',
        'mismatch'
    ) AS status
FROM daily_tx dt
LEFT JOIN daily_repay dr ON dt.settlement_date = dr.settlement_date AND dt.merchant_id = dr.merchant_id
