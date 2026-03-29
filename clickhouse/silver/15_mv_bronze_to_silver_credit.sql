-- MV: bronze.pg_transactions_raw → silver.user_active_credit
-- AggregatingMergeTree requires -State combinators
-- Only approved transactions contribute to active credit exposure
CREATE MATERIALIZED VIEW IF NOT EXISTS silver.mv_user_active_credit
TO silver.user_active_credit AS
SELECT
    user_id,
    sumState(amount) AS active_exposure
FROM bronze.pg_transactions_raw
WHERE __op != 'd'
  AND status = 'approved'
GROUP BY user_id;
