-- Intermediate: user credit history — all transactions + repayments per user
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
FROM {{ ref('stg_transactions') }} t
LEFT JOIN {{ ref('stg_repayments') }} r
    ON t.transaction_id = r.transaction_id
