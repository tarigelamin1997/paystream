{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='(date)',
        schema='gold',
        alias='risk_dashboard',
        order_by='(date)'
    )
}}

WITH daily_metrics AS (
    SELECT
        toDate(created_at) AS date,
        countIf(status = 'approved') / count() AS approval_rate,
        countIf(status = 'declined') / count() AS decline_rate,
        avg(decision_latency_ms) AS avg_decision_latency_ms,
        toUInt32(0) AS fraud_flag_count,
        sumIf(amount, status = 'approved') AS total_exposure
    FROM {{ ref('stg_transactions') }}
    GROUP BY toDate(created_at)
),
overdue AS (
    SELECT
        due_date AS date,
        countIf(status = 'overdue') / count() AS overdue_rate
    FROM {{ ref('stg_repayments') }}
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
{% if is_incremental() %}
WHERE dm.date >= (SELECT max(date) - INTERVAL 3 DAY FROM {{ this }})
{% endif %}
