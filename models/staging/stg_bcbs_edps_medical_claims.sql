-- Staging model for BCBS EDPS (encounter) medical claims
-- 1:1 with the bcbsm_edps_claim source: JSON fields are extracted under their source names, no renaming,
-- hard-coding, or filtering. Mapping to the shared claim contract happens in int_bcbs_medical_claim_combined.

select
    encounter_internal_control_number,
    reporting_year_month,
    allowed_indicator,
    diagnosis_codes,
    file_group_id,
    cast(parse_json(data):enterprise_person_identifier as {{ dbt.type_string() }}) as enterprise_person_identifier,
    cast(parse_json(data):medicare_beneficiary_identifier as {{ dbt.type_string() }}) as medicare_beneficiary_identifier,
    cast(parse_json(data):additional_diagnoses_code as {{ dbt.type_string() }}) as additional_diagnoses_code
from {{ source('bcbs', 'bcbsm_edps_claim') }}
