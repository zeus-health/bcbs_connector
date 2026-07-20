-- Staging model for BCBS commercial HMO members
-- Pulls raw columns from commercial_hmo_member with type casts only

select
    cast(cursubid as {{ dbt.type_string() }}) as cursubid,
    cast(bcmbrnbr as {{ dbt.type_string() }}) as bcmbrnbr,
    cast(mem_first_name as {{ dbt.type_string() }}) as mem_first_name,
    cast(mem_last_name as {{ dbt.type_string() }}) as mem_last_name,
    cast(mem_birth_dt as date) as mem_birth_dt,
    cast(mem_gender as {{ dbt.type_string() }}) as mem_gender,
    cast(mem_mth_st_dt as date) as mem_mth_st_dt,
    cast(mem_mth_end_dt as date) as mem_mth_end_dt,
    payer,
    market,
    cast(netwk_prod_cd as {{ dbt.type_string() }}) as netwk_prod_cd,
    lob,
    cast(mem_street as {{ dbt.type_string() }}) as mem_street,
    cast(mem_street2 as {{ dbt.type_string() }}) as mem_street2,
    cast(mem_city as {{ dbt.type_string() }}) as mem_city,
    cast(mem_state as {{ dbt.type_string() }}) as mem_state,
    cast(mem_zip_cd as {{ dbt.type_string() }}) as mem_zip_cd,
    cast(mem_phone_num as {{ dbt.type_string() }}) as mem_phone_num,
    cast(pcp_npi as {{ dbt.type_string() }}) as pcp_npi,
    cast(mem_mth_cnt as {{ dbt.type_int() }}) as mem_mth_cnt,
    filename,
    cast(date_id as date) as date_id,
    s3_path,
    _run_time
from {{ source('bcbs', 'commercial_hmo_member') }}
