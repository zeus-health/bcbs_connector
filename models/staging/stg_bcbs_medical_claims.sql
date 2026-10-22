-- Staging model for BCBS medical claims
-- 1:1 with the bcbsm_med_claim source: JSON fields are extracted under their source names, no renaming,
-- hard-coding, or filtering. Mapping to the shared claim contract happens in int_bcbs_medical_claim_combined.

select
    claim_id,
    claim_line_id,
    file_group_id,
    cast(parse_json(data):revenue_code as {{ dbt.type_string() }}) as revenue_code,
    cast(parse_json(data):place_of_service as {{ dbt.type_string() }}) as place_of_service,
    cast(parse_json(data):subscriber_id as {{ dbt.type_string() }}) as subscriber_id,
    cast(parse_json(data):mbi_number as {{ dbt.type_string() }}) as mbi_number,
    cast(parse_json(data):line_of_business as {{ dbt.type_string() }}) as line_of_business,
    cast(parse_json(data):date_of_service_to as {{ dbt.type_string() }}) as date_of_service_to,
    cast(parse_json(data):inpatient_admit_date as {{ dbt.type_string() }}) as inpatient_admit_date,
    cast(parse_json(data):inpatient_discharge_date as {{ dbt.type_string() }}) as inpatient_discharge_date,
    cast(parse_json(data):source_system_code as {{ dbt.type_string() }}) as source_system_code,
    cast(parse_json(data):type_of_admission as {{ dbt.type_string() }}) as type_of_admission,
    cast(parse_json(data):patient_discharge_status as {{ dbt.type_string() }}) as patient_discharge_status,
    cast(parse_json(data):bill_type as {{ dbt.type_string() }}) as bill_type,
    cast(parse_json(data):processed_drg_code as {{ dbt.type_string() }}) as processed_drg_code,
    cast(parse_json(data):units_of_service as {{ dbt.type_string() }}) as units_of_service,
    cast(parse_json(data):procedure_code as {{ dbt.type_string() }}) as procedure_code,
    cast(parse_json(data):adjustment_code as {{ dbt.type_string() }}) as adjustment_code,
    cast(parse_json(data):rendering_provider_npi as {{ dbt.type_string() }}) as rendering_provider_npi,
    cast(parse_json(data):billing_provider_npi as {{ dbt.type_string() }}) as billing_provider_npi,
    cast(parse_json(data):paid_date as {{ dbt.type_string() }}) as paid_date,
    cast(parse_json(data):paid_amount as {{ dbt.type_string() }}) as paid_amount,
    cast(parse_json(data):copay_amount as {{ dbt.type_string() }}) as copay_amount,
    cast(parse_json(data):deductible_amount as {{ dbt.type_string() }}) as deductible_amount,
    cast(parse_json(data):cob_amount as {{ dbt.type_string() }}) as cob_amount,
    {% for i in range(1, 26) -%}
    cast(parse_json(data):icd_diagnoses_{{ i }} as {{ dbt.type_string() }}) as icd_diagnoses_{{ i }},
    {% endfor -%}
    {% for i in range(1, 6) -%}
    cast(parse_json(data):icd_procedure_{{ i }} as {{ dbt.type_string() }}) as icd_procedure_{{ i }}{{ "," if not loop.last }}
    {% endfor -%}
from {{ source('bcbs', 'bcbsm_med_claim') }}
