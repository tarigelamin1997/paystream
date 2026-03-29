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
FROM {{ source('silver', 'repayments_silver') }} FINAL
