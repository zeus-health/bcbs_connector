-- ============================================================================
-- NPI Validation
-- ============================================================================

{% macro validate_npi(column_name) %}
{#-
    Validate an NPI using the Luhn algorithm and return the normalized 10-digit value.
-#}
{% set numeric_npi = "regexp_replace(cast(" ~ column_name ~ " as " ~ dbt.type_string() ~ "), '[^0-9]', '')" %}
case
    when regexp_like({{ numeric_npi }}, '^[0-9]{10}$')
        and (
            (
                24
                + (((cast(substr({{ numeric_npi }}, 1, 1) as int) * 2) % 10) + floor((cast(substr({{ numeric_npi }}, 1, 1) as int) * 2) / 10))
                + cast(substr({{ numeric_npi }}, 2, 1) as int)
                + (((cast(substr({{ numeric_npi }}, 3, 1) as int) * 2) % 10) + floor((cast(substr({{ numeric_npi }}, 3, 1) as int) * 2) / 10))
                + cast(substr({{ numeric_npi }}, 4, 1) as int)
                + (((cast(substr({{ numeric_npi }}, 5, 1) as int) * 2) % 10) + floor((cast(substr({{ numeric_npi }}, 5, 1) as int) * 2) / 10))
                + cast(substr({{ numeric_npi }}, 6, 1) as int)
                + (((cast(substr({{ numeric_npi }}, 7, 1) as int) * 2) % 10) + floor((cast(substr({{ numeric_npi }}, 7, 1) as int) * 2) / 10))
                + cast(substr({{ numeric_npi }}, 8, 1) as int)
                + (((cast(substr({{ numeric_npi }}, 9, 1) as int) * 2) % 10) + floor((cast(substr({{ numeric_npi }}, 9, 1) as int) * 2) / 10))
            ) % 10
        ) = (
            (10 - cast(substr({{ numeric_npi }}, 10, 1) as int)) % 10
        )
        then {{ numeric_npi }}
    else cast(null as {{ dbt.type_string() }})
end
{% endmacro %}
