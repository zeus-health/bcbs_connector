-- Intermediate model for BCBS member eligibility: normalize, dedupe, and map to Tuva input layer
-- Payer, market, and LOB are hard-coded per DE-3263 (raw_data metadata is incorrect)
-- Dedup handles duplicate file uploads via _run_time
-- Column renaming from raw names to Tuva shape happens here (not in staging)
-- UNIONs HMO and PPO staging models (one staging model per raw table)

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
    payer,
    market,
    netwk_prod_cd,
    lob,
    mem_street,
    mem_city,
    mem_state,
    mem_zip_cd,
    mem_phone_num,
    mem_mth_cnt,
    filename,
    date_id,
    s3_path,
    _run_time,
    null as source_plan_type
  from {{ ref('stg_bcbs_member') }}
),

-- Only use the latest snapshot file — each BCBS file is cumulative, so the
-- most recent file is the authoritative source for all eligibility months.
latest_snapshot as (
  select *
  from unioned
  where date_id = (select max(date_id) from unioned)
),

ranked as (
  select
    s.*,
    concat(s.cursubid, s.bcmbrnbr) as member_id,
    row_number() over (
      partition by concat(s.cursubid, s.bcmbrnbr), date_trunc('month', s.mem_mth_st_dt)
      order by s.mem_mth_cnt desc, s.mem_mth_end_dt desc, s._run_time desc
    ) as rn
  from latest_snapshot as s
  where concat(s.cursubid, s.bcmbrnbr) is not null
)

select
    cast(concat('bcbs', '|', 'MA', '|', 'COMM', '.', s.member_id) as {{ dbt.type_string() }}) as person_id,
    cast(s.member_id as {{ dbt.type_string() }}) as member_id,
    cast(s.member_id as {{ dbt.type_string() }}) as subscriber_id,
    cast(case
      when upper(s.mem_gender) = 'M' then 'male'
      when upper(s.mem_gender) = 'F' then 'female'
      else 'unknown'
    end as {{ dbt.type_string() }}) as gender,
    cast(null as {{ dbt.type_string() }}) as race,
    cast(s.mem_birth_dt as date) as birth_date,
    cast(null as date) as death_date,
    -- death_flag = 1 when death_date is not null; auto-updates if BCBS starts sending death dates
    cast(case when death_date is not null then 1 else 0 end as {{ dbt.type_int() }}) as death_flag,
    cast(s.mem_mth_st_dt as date) as enrollment_start_date,
    cast(s.mem_mth_end_dt as date) as enrollment_end_date,
    cast('bcbs' as {{ dbt.type_string() }}) as payer,
    -- HACK: Payer type is null so CMS HCC flows through since currently it only allows medicare + null payer types
    cast(null as {{ dbt.type_string() }}) as payer_type,
    cast(s.source_plan_type as {{ dbt.type_string() }}) as plan,
    cast(null as {{ dbt.type_string() }}) as original_reason_entitlement_code,
    cast(null as {{ dbt.type_string() }}) as dual_status_code,
    cast(null as {{ dbt.type_string() }}) as medicare_status_code,
    cast(null as {{ dbt.type_string() }}) as group_id,
    cast(null as {{ dbt.type_string() }}) as group_name,
    cast(null as {{ dbt.type_string() }}) as name_suffix,
    cast(s.mem_first_name as {{ dbt.type_string() }}) as first_name,
    cast(null as {{ dbt.type_string() }}) as middle_name,
    cast(s.mem_last_name as {{ dbt.type_string() }}) as last_name,
    cast(null as {{ dbt.type_string() }}) as email,
    cast(null as {{ dbt.type_string() }}) as ethnicity,
    cast(null as {{ dbt.type_string() }}) as social_security_number,
    cast(null as {{ dbt.type_string() }}) as subscriber_relation,
    cast(null as {{ dbt.type_string() }}) as enrollment_status,
    cast(null as {{ dbt.type_int() }}) as hospice_flag,
    cast(null as {{ dbt.type_int() }}) as institutional_snp_flag,
    cast(null as {{ dbt.type_int() }}) as long_term_institutional_flag,
    cast(s.mem_street as {{ dbt.type_string() }}) as address,
    cast(s.mem_city as {{ dbt.type_string() }}) as city,
    cast(s.mem_state as {{ dbt.type_string() }}) as state,
    cast(s.mem_zip_cd as {{ dbt.type_string() }}) as zip_code,
    cast(s.mem_phone_num as {{ dbt.type_string() }}) as phone,
    cast('bcbs|MA|COMM' as {{ dbt.type_string() }}) as data_source,
    cast(s.filename as {{ dbt.type_string() }}) as file_name,
    cast(s.date_id as date) as file_date,
    cast(s._run_time as {{ dbt.type_timestamp() }}) as ingest_datetime,
    cast(s.source_plan_type as {{ dbt.type_string() }}) as x_program_type,
    cast('MA' as {{ dbt.type_string() }}) as x_market,
    cast(s.mem_mth_cnt as {{ dbt.type_int() }}) as x_mem_mth_cnt
from ranked as s
where s.rn = 1
