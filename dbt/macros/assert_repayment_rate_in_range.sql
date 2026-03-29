{% macro assert_repayment_rate_in_range(model, rate_column='repayment_rate') %}

SELECT *
FROM {{ model }}
WHERE {{ rate_column }} < 0.0 OR {{ rate_column }} > 1.0

{% endmacro %}
