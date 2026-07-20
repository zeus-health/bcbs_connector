-- Intermediate BCBS provider attribution: derived from HMO/PPO member data
-- BCBS embeds PCP attribution directly in the member files (no separate provider file)
-- Payer, market are hard-coded per DE-3263

with unioned as (
  select
    cursubid,
    bcmbrnbr,
    mem_first_name,
    mem_last_name,
    mem_birth_dt,
    mem_gender,
    mem_mth_st_dt,
    mem_mth_end_dt,
    mem_street,
    mem_street2,
    mem_city,
    mem_state,
    mem_zip_cd,
    mem_phone_num,
    pcp_npi,
    lob,
    filename,
    date_id,
    s3_path,
    _run_time,
    'HMO' as source_plan_type
  from {{ ref('stg_bcbs_commercial_hmo_member') }}
  union all
  select
    cursubid,
    bcmbrnbr,
    mem_first_name,
    mem_last_name,
    mem_birth_dt,
    mem_gender,
    mem_mth_st_dt,
    mem_mth_end_dt,
    mem_street,
    mem_street2,
    mem_city,
    mem_state,
    mem_zip_cd,
    mem_phone_num,
    pcp_npi,
    lob,
    filename,
    date_id,
    s3_path,
    _run_time,
    'PPO' as source_plan_type
  from {{ ref('stg_bcbs_commercial_ppo_member') }}
),

ranked as (
  select
    u.*,
    concat(u.cursubid, u.bcmbrnbr) as member_id,
    row_number() over (
      partition by concat(u.cursubid, u.bcmbrnbr), u.source_plan_type, date_format(u.mem_mth_st_dt, 'yyyyMM')
      order by u.date_id desc, u.mem_mth_end_dt desc, u._run_time desc
    ) as rn
  from unioned as u
  where concat(u.cursubid, u.bcmbrnbr) is not null
)

select
    cast(concat('bcbs', '|', 'MA', '|', 'COMM', '.', r.member_id) as {{ dbt.type_string() }}) as person_id,
    cast(r.member_id as {{ dbt.type_string() }}) as patient_id,
    cast(r.member_id as {{ dbt.type_string() }}) as member_id,
    cast('bcbs' as {{ dbt.type_string() }}) as payer,
    cast(r.source_plan_type as {{ dbt.type_string() }}) as plan,
    cast('bcbs|MA|COMM' as {{ dbt.type_string() }}) as data_source,
    {{ validate_npi('r.pcp_npi') }} as payer_attributed_provider,
    cast(null as {{ dbt.type_string() }}) as payer_attributed_provider_practice,
    cast(null as {{ dbt.type_string() }}) as payer_attributed_provider_organization,
    cast('COMM' as {{ dbt.type_string() }}) as payer_attributed_provider_lob,
    cast(null as {{ dbt.type_string() }}) as custom_attributed_provider,
    cast(null as {{ dbt.type_string() }}) as custom_attributed_provider_practice,
    cast(null as {{ dbt.type_string() }}) as custom_attributed_provider_organization,
    cast('COMM' as {{ dbt.type_string() }}) as custom_attributed_provider_lob,
    cast(r.mem_mth_st_dt as date) as member_effective_date,
    cast(r.mem_mth_end_dt as date) as member_term_date,
    cast(date_format(r.mem_mth_st_dt, 'yyyyMM') as {{ dbt.type_string() }}) as year_month,
    cast(r.filename as {{ dbt.type_string() }}) as file_name,
    cast(r.date_id as date) as file_date,
    cast(r._run_time as {{ dbt.type_timestamp() }}) as ingest_datetime,
    cast(null as {{ dbt.type_string() }}) as x_provider_specialty,
    cast(r.source_plan_type as {{ dbt.type_string() }}) as x_program_type,
    cast('MA' as {{ dbt.type_string() }}) as x_market
from ranked as r
where r.rn = 1
