{% macro get_user_feature_as_of(user_id_col, feature_name, as_of_ts) %}
(
    SELECT {{ feature_name }}
    FROM feature_store.user_credit_features
    WHERE user_id = {{ user_id_col }}
      AND valid_from <= {{ as_of_ts }}
      AND (valid_to > {{ as_of_ts }} OR valid_to IS NULL)
    ORDER BY snapshot_ts DESC
    LIMIT 1
)
{% endmacro %}
