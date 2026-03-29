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