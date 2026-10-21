-- Staging model for BCBS members
-- Members are sourced from the member fields on bcbsm_med_claim (no standalone member file).
-- 1:1 with the source: JSON fields are extracted under their source names, no renaming, hard-coding,
-- or deduplication. Mapping to the Tuva shape happens in int_bcbs_member_eligibility.

select
    file_group_id,
    cast(parse_json(data):subscriber_id as {{ dbt.type_string() }}) as subscriber_id,
    cast(parse_json(data):mbi_number as {{ dbt.type_string() }}) as mbi_number,
    cast(parse_json(data):member_first_name as {{ dbt.type_string() }}) as member_first_name,
    cast(parse_json(data):member_last_name as {{ dbt.type_string() }}) as member_last_name,
    cast(parse_json(data):member_date_of_birth as {{ dbt.type_string() }}) as member_date_of_birth,
    cast(parse_json(data):member_gender as {{ dbt.type_string() }}) as member_gender,
    cast(parse_json(data):line_of_business as {{ dbt.type_string() }}) as line_of_business,
    cast(parse_json(data):pcp_npi as {{ dbt.type_string() }}) as pcp_npi
from {{ source('bcbs', 'bcbsm_med_claim') }}
