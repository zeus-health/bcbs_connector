-- Staging model for BCBS commercial HMO members
-- Pulls raw columns from commercial_hmo_member with type casts only

select distinct
    cast(parse_json(data):subscriber_id as {{ dbt.type_string() }}) as cursubid,
    cast(parse_json(data):mbi_number as {{ dbt.type_string() }}) as bcmbrnbr,
    cast(parse_json(data):member_first_name as {{ dbt.type_string() }}) as mem_first_name,
    cast(parse_json(data):member_last_name as {{ dbt.type_string() }}) as mem_last_name,
    to_date(cast(parse_json(data):member_date_of_birth as string), 'YYYYMMDD') as mem_birth_dt,
    cast(parse_json(data):member_gender as {{ dbt.type_string() }}) as mem_gender,
    -- HACK: No start or stop dates so putting in as wide a span as possible
    cast('1990-01-01' as date) as mem_mth_st_dt,
    cast('2099-01-01' as date) as mem_mth_end_dt,
    cast('BCBS' as {{ dbt.type_string() }}) as payer,
    null as market,
    cast(null as {{ dbt.type_string() }}) as netwk_prod_cd,
    cast(parse_json(data):line_of_business as string) as lob,
    cast(null as {{ dbt.type_string() }}) as mem_street,
    cast(null as {{ dbt.type_string() }}) as mem_street2,
    cast(null as {{ dbt.type_string() }}) as mem_city,
    cast(null as {{ dbt.type_string() }}) as mem_state,
    cast(null as {{ dbt.type_string() }}) as mem_zip_cd,
    cast(null as {{ dbt.type_string() }}) as mem_phone_num,
    cast(parse_json(data):pcp_npi as {{ dbt.type_string() }}) as pcp_npi,
    cast(null as {{ dbt.type_int() }}) as mem_mth_cnt,
    null as filename,
    current_date as date_id,
    null as s3_path,
    current_timestamp as _run_time
from {{ source('bcbs', 'bcbsm_med_claim') }}
