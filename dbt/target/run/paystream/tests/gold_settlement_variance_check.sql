
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- Gold: settlement_reconciliation should not have extreme variance (> 100%)
-- severity: warn (surface anomalies without blocking)


SELECT 1
WHERE (SELECT countIf(abs(variance_pct) > 100) FROM `gold`.`settlement_reconciliation`) > 0
    ) dbt_internal_test