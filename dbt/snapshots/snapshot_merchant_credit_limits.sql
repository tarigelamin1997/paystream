{% snapshot snapshot_merchant_credit_limits %}
{{
    config(
        target_database='silver',
        target_schema='silver',
        unique_key='merchant_id',
        strategy='check',
        check_cols=['credit_limit', 'risk_tier', 'commission_rate'],
        invalidate_hard_deletes=True
    )
}}
SELECT
    merchant_id,
    merchant_name,
    merchant_category,
    risk_tier,
    commission_rate,
    credit_limit,
    updated_at
FROM silver.merchants_silver FINAL
{% endsnapshot %}
