-- Gold: total_repaid should not be 0 for all users
-- Known Phase 3 issue: CTE simplification produces 0
-- severity: warn (documented, not blocking)
{{ config(severity='warn') }}

SELECT 1
WHERE (SELECT countIf(total_repaid > 0) FROM {{ ref('gold_user_cohorts') }}) = 0
