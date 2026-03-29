-- Intermediate: transaction enriched with user and merchant dimensions
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
FROM {{ ref('stg_transactions') }} t
LEFT JOIN {{ ref('stg_users') }} u ON t.user_id = u.user_id
LEFT JOIN {{ ref('stg_merchants') }} m ON t.merchant_id = m.merchant_id
