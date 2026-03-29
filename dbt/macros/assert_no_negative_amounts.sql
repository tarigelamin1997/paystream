{% macro assert_no_negative_amounts(model, column_name='amount') %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} < 0

{% endmacro %}
