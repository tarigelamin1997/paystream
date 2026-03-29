{% macro mask_pii(column) %}
    hex(SHA256(toString({{ column }})))
{% endmacro %}
