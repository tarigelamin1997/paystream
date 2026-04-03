
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- Contract: feature_store.user_credit_features must have required columns
-- Enforces contracts/gold_to_feature_store.yml


SELECT 1
WHERE (
    SELECT count(*)
    FROM system.columns
    WHERE database = 'feature_store'
      AND table = 'user_credit_features'
      AND name IN (
        'user_id', 'snapshot_ts', 'valid_from', 'valid_to',
        'feature_version', 'tx_velocity_7d', 'tx_velocity_30d',
        'avg_tx_amount_30d', 'repayment_rate_90d', 'merchant_diversity_30d',
        'declined_rate_7d', 'active_installments', 'days_since_first_tx',
        '_ingested_at'
      )
) < 14
    ) dbt_internal_test