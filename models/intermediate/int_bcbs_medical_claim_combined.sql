-- Combines BCBS medical claims from the medical claims (MED) file and
-- the EDPS (encounter) file. Each source is mapped from its raw staging columns onto
-- a shared claim contract (renames, type conversions, and hard-coded values), then unioned.
-- Only allowed EDPS encounters (allowed_indicator = 'A') are included.

with med_claims as (

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
        cast(null as {{ dbt.type_string() }}) as netpay,
        paid_amount as paid,
        cast(null as {{ dbt.type_string() }}) as coins_amt,
        copay_amount as copay_amt,
        deductible_amount as deduct_amt,
        cast(null as {{ dbt.type_string() }}) as dw_mem_liab_amt,
        cob_amount as cobamt,
        cast(10 as {{ dbt.type_string() }}) as icd_subm_ind,
        {% for i in range(1, 26) -%}
        icd_diagnoses_{{ i }} as icd_diag{{ i }}_cd,
        {% endfor -%}
        {% for i in range(1, 6) -%}
        icd_procedure_{{ i }} as icd_proc{{ i }}_cd,
        {% endfor -%}
        cast(null as {{ dbt.type_string() }}) as dw_netwk_ind,
        cast(null as {{ dbt.type_string() }}) as curr_clm_ind,
        current_date as date_id,
        current_timestamp as _run_time,
        cast(null as {{ dbt.type_string() }}) as s3_path,
        file_group_id as filename,
        cast('MED' as {{ dbt.type_string() }}) as data_source
    from {{ ref('stg_bcbs_medical_claims') }}

),

edps_claims as (

    select
        cast(encounter_internal_control_number as {{ dbt.type_string() }}) as int_clm_num,
        cast(1 as {{ dbt.type_int() }}) as clm_line_num,
        cast(null as {{ dbt.type_string() }}) as revenue_cd,
        cast(null as {{ dbt.type_string() }}) as cms_place_srv_cd,
        enterprise_person_identifier as cursubid,
        medicare_beneficiary_identifier as bcmbrnbr,
        cast('BCBS' as {{ dbt.type_string() }}) as payer,
        cast(null as {{ dbt.type_string() }}) as market,
        cast('MA' as {{ dbt.type_string() }}) as lob,
        to_date(reporting_year_month, 'YYYYMM') as svcdt,
        cast(null as date) as admitdt,
        cast(null as date) as dischdt,
        cast(null as {{ dbt.type_string() }}) as admit_source_cd,
        cast(null as {{ dbt.type_string() }}) as type_admit_cd,
        cast(null as {{ dbt.type_string() }}) as disch_stat_cd,
        -- Harcoding an eligible bill type code in order to get the data through
        cast(111 as {{ dbt.type_string() }}) as bill_type_cd,
        cast(null as {{ dbt.type_string() }}) as drg_cd,
        cast(null as {{ dbt.type_string() }}) as srv_units,
        cast(null as {{ dbt.type_string() }}) as dw_srv_units,
        cast(null as {{ dbt.type_string() }}) as hcpcs_proc_cd,
        cast(null as {{ dbt.type_string() }}) as cpt_proc_cd,
        cast(null as {{ dbt.type_string() }}) as cpt_pmod1_cd,
        cast(null as {{ dbt.type_string() }}) as cpt_pmod2_cd,
        cast(null as {{ dbt.type_string() }}) as cpt_pmod3_cd,
        cast(null as {{ dbt.type_string() }}) as sprovnpi,
        cast(null as {{ dbt.type_string() }}) as bprovnpi,
        cast(null as date) as pddate,
        cast(null as {{ dbt.type_string() }}) as charge_amt,
        cast(null as {{ dbt.type_string() }}) as netpay,
        cast(null as {{ dbt.type_string() }}) as paid,
        cast(null as {{ dbt.type_string() }}) as coins_amt,
        cast(null as {{ dbt.type_string() }}) as copay_amt,
        cast(null as {{ dbt.type_string() }}) as deduct_amt,
        cast(null as {{ dbt.type_string() }}) as dw_mem_liab_amt,
        cast(null as {{ dbt.type_string() }}) as cobamt,
        cast(10 as {{ dbt.type_string() }}) as icd_subm_ind,
        cast(diagnosis_codes as {{ dbt.type_string() }}) as icd_diag1_cd,
        -- EDPS packs the additional ICD-10 diagnosis codes into a single fixed-width string.
        -- Each code is left-justified in its slot and followed by a '*<indicator>*'
        -- delimiter ('*A*') when populated, or '* *' when the slot is empty. Extract
        -- the code (capture group 1) preceding the Nth populated delimiter; empty
        -- slots and unfilled positions yield NULL.
        {% for i in range(2, 26) -%}
        cast(regexp_substr(additional_diagnoses_code, '([A-Z0-9]+)\\s*\\*[^*\\s]\\*', 1, {{ i }} - 1, 'e', 1) as {{ dbt.type_string() }}) as icd_diag{{ i }}_cd,
        {% endfor -%}
        cast(null as {{ dbt.type_string() }}) as icd_proc1_cd,
        cast(null as {{ dbt.type_string() }}) as icd_proc2_cd,
        cast(null as {{ dbt.type_string() }}) as icd_proc3_cd,
        cast(null as {{ dbt.type_string() }}) as icd_proc4_cd,
        cast(null as {{ dbt.type_string() }}) as icd_proc5_cd,
        cast(null as {{ dbt.type_string() }}) as dw_netwk_ind,
        cast(null as {{ dbt.type_string() }}) as curr_clm_ind,
        current_date as date_id,
        current_timestamp as _run_time,
        cast(null as {{ dbt.type_string() }}) as s3_path,
        file_group_id as filename,
        cast('EDPS' as {{ dbt.type_string() }}) as data_source
    from {{ ref('stg_bcbs_edps_medical_claims') }}
    where allowed_indicator = 'A'

)

select * from med_claims

union all

select * from edps_claims
