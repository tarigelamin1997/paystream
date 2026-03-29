{% snapshot snapshot_user_credit_tier %}
{{
    config(
        target_database='silver',
        target_schema='silver',
        unique_key='user_id',
        strategy='check',
        check_cols=['credit_tier', 'credit_limit', 'kyc_status'],
        invalidate_hard_deletes=True
    )
}}
SELECT
    user_id,
    credit_tier,
    credit_limit,
    kyc_status,
    updated_at
FROM silver.users_silver FINAL
{% endsnapshot %}
