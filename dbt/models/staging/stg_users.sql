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
FROM {{ source('silver', 'users_silver') }} FINAL
