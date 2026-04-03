-- Gold: risk_dashboard should have continuous daily records (no date gaps)
-- severity: warn (surface missing days without blocking)
{{ config(severity='warn') }}

SELECT 1
WHERE (
    SELECT dateDiff('day', min(date), max(date)) + 1 - count(DISTINCT date)
    FROM {{ ref('gold_risk_dashboard') }}
) > 0
