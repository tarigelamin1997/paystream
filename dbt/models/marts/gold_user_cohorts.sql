{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='(cohort_month, user_id)',
        schema='gold',
        alias='user_cohorts',
        order_by='(cohort_month, user_id)'
    )
}}

SELECT
    toStartOfMonth(min(created_at)) AS cohort_month,
    user_id,
    sum(amount) AS ltv,
    toUInt32(count()) AS total_transactions,
    toDecimal64(0, 2) AS total_repaid,
    toUInt8(dateDiff('month', min(created_at), max(created_at))) AS retention_months,
    if(count() > 1, toFloat32((count() - 1)) / toFloat32(count()), toFloat32(0)) AS reorder_rate
FROM {{ ref('stg_transactions') }}
GROUP BY user_id
{% if is_incremental() %}
HAVING toStartOfMonth(min(created_at)) >= (SELECT max(cohort_month) - INTERVAL 3 MONTH FROM {{ this }})
{% endif %}
