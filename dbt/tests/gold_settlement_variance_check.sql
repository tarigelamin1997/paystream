-- Gold: settlement_reconciliation should not have extreme variance (> 100%)
-- severity: warn (surface anomalies without blocking)
{{ config(severity='warn') }}

SELECT 1
WHERE (SELECT countIf(abs(variance_pct) > 100) FROM {{ ref('gold_settlement_reconciliation') }}) > 0
