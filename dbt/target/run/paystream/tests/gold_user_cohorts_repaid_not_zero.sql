
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- Gold: total_repaid should not be 0 for all users
-- Known Phase 3 issue: CTE simplification produces 0
-- severity: warn (documented, not blocking)


SELECT 1
WHERE (SELECT countIf(total_repaid > 0) FROM `gold`.`user_cohorts`) = 0
    ) dbt_internal_test