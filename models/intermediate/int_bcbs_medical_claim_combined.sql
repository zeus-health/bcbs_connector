-- Combines BCBS medical claims from the medical claims (MED) file with the verdicts from
-- the EDPS (encounter) file, mapped from raw staging columns onto the shared claim contract
-- (renames, type conversions, and hard-coded values).
-- EDPS rows are not claims of their own. Mirroring the insights BCBSM matcher, each EDPS
-- encounter is matched to the MED claims sharing its (MBI, service start, service end) key,
-- and diagnoses EDPS marked disallowed (allowed_indicator = 'D') are stripped from those claims.

with edps_latest as (

    -- Latest verdict per encounter and diagnosis
    select *
    from {{ ref('stg_bcbs_edps_medical_claims') }}
    qualify row_number() over (
        partition by encounter_internal_control_number, diagnosis_codes
        order by reporting_year_month desc, created_at desc
    ) = 1

),

disallowed as (

    select distinct mbi_number, service_start_date, service_end_date, diagnosis_codes
    from edps_latest
    where allowed_indicator = 'D'

),

-- A diagnosis disallowed on an encounter is disallowed on every line of every claim matching it
claim_disallowed_dx as (

    select
        m.claim_id,
        array_agg(distinct d.diagnosis_codes) as disallowed_dx
    from {{ ref('stg_bcbs_medical_claims') }} as m
    inner join disallowed as d
        on m.mbi_number = d.mbi_number
        and m.date_of_service_from = d.service_start_date
        and m.date_of_service_to = d.service_end_date
    group by m.claim_id

),

-- Drop disallowed diagnoses and shift the remaining ones left so there are no gaps
med_kept_dx as (

    select
        m.*,
        array_construct_compact(
            {% for i in range(1, 26) -%}
            iff(array_contains(m.icd_diagnoses_{{ i }}::variant, d.disallowed_dx), null, m.icd_diagnoses_{{ i }}){{ "," if not loop.last }}
            {% endfor -%}
        ) as kept_dx
    from {{ ref('stg_bcbs_medical_claims') }} as m
    left join claim_disallowed_dx as d
        on m.claim_id = d.claim_id

)

select
    cast(claim_id as {{ dbt.type_string() }}) as int_clm_num,
    cast(claim_line_id as {{ dbt.type_int() }}) as clm_line_num,
    revenue_code as revenue_cd,
    place_of_service as cms_place_srv_cd,
    subscriber_id as cursubid,
    mbi_number as bcmbrnbr,
    cast('BCBS' as {{ dbt.type_string() }}) as payer,
    cast(null as {{ dbt.type_string() }}) as market,
    line_of_business as lob,
    to_date(date_of_service_to, 'YYYYMMDD') as svcdt,
    to_date(inpatient_admit_date, 'YYYYMMDD') as admitdt,
    to_date(inpatient_discharge_date, 'YYYYMMDD') as dischdt,
    source_system_code as admit_source_cd,
    type_of_admission as type_admit_cd,
    patient_discharge_status as disch_stat_cd,
    bill_type as bill_type_cd,
    processed_drg_code as drg_cd,
    units_of_service as srv_units,
    cast(null as {{ dbt.type_string() }}) as dw_srv_units,
    procedure_code as hcpcs_proc_cd,
    procedure_code as cpt_proc_cd,
    adjustment_code as cpt_pmod1_cd,
    cast(null as {{ dbt.type_string() }}) as cpt_pmod2_cd,
    cast(null as {{ dbt.type_string() }}) as cpt_pmod3_cd,
    rendering_provider_npi as sprovnpi,
    billing_provider_npi as bprovnpi,
    to_date(paid_date, 'YYYYMMDD') as pddate,
    cast(null as {{ dbt.type_string() }}) as charge_amt,
    paid_amount as netpay,
    allowed_amount as paid,
    cast(null as {{ dbt.type_string() }}) as coins_amt,
    copay_amount as copay_amt,
    deductible_amount as deduct_amt,
    cast(null as {{ dbt.type_string() }}) as dw_mem_liab_amt,
    cob_amount as cobamt,
    cast(10 as {{ dbt.type_string() }}) as icd_subm_ind,
    {% for i in range(1, 26) -%}
    cast(kept_dx[{{ i - 1 }}] as {{ dbt.type_string() }}) as icd_diag{{ i }}_cd,
    {% endfor -%}
    {% for i in range(1, 6) -%}
    icd_procedure_{{ i }} as icd_proc{{ i }}_cd,
    {% endfor -%}
    cast(null as {{ dbt.type_string() }}) as dw_netwk_ind,
    cast(null as {{ dbt.type_string() }}) as curr_clm_ind,
    extract_year_month,
    current_date as date_id,
    current_timestamp as _run_time,
    cast(null as {{ dbt.type_string() }}) as s3_path,
    file_group_id as filename,
    cast('MED' as {{ dbt.type_string() }}) as data_source
from med_kept_dx
