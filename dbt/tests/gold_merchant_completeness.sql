-- Gold: merchant_daily_kpis should contain all 200 merchants
-- severity: warn (completeness check, not blocking)
{{ config(severity='warn') }}

SELECT 1
WHERE (SELECT count(DISTINCT merchant_id) FROM {{ ref('gold_merchant_daily_kpis') }}) < 200
