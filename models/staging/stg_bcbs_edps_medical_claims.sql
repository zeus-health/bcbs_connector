-- Staging model for BCBS EDPS (encounter) medical claims
-- 1:1 with the bcbsm_edps_claim source: JSON fields are extracted under their source names, no renaming,
-- hard-coding, or filtering. Each row is one diagnosis verdict on an encounter; the verdicts are applied
-- to the matching MED claims in int_bcbs_medical_claim_combined.

select
    encounter_internal_control_number,
    mbi_number,
    reporting_year_month,
    allowed_indicator,
    diagnosis_codes,
    file_group_id,
    created_at,
    cast(parse_json(data):service_start_date as {{ dbt.type_string() }}) as service_start_date,
    cast(parse_json(data):service_end_date as {{ dbt.type_string() }}) as service_end_date
from {{ source('bcbs', 'bcbsm_edps_claim') }}
