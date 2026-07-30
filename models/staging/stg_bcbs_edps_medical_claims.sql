with source as (

    select
        *,
        cast(parse_json(data):diagnosis_codes as {{ dbt.type_string() }}) as diagnosis_codes_raw
    from {{ source('bcbs', 'bcbsm_edps_claim') }}
    where allowed_indicator = 'A'

)

select
    cast(encounter_internal_control_number as {{ dbt.type_string() }}) as int_clm_num,
    cast(1 as {{ dbt.type_int() }}) as clm_line_num,
    cast(null as {{ dbt.type_string() }}) as revenue_cd,
    cast(null as {{ dbt.type_string() }}) as cms_place_srv_cd,
    cast(parse_json(data):enterprise_person_identifier as {{ dbt.type_string() }}) as cursubid,
    cast(parse_json(data):medicare_beneficiary_identifier as {{ dbt.type_string() }}) as bcmbrnbr,
    cast('BCBS' as string) as payer,
    null as market,
    cast('MA' as string) as lob,
    cast(null as date) as svcdt,
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
    -- EDPS packs all ICD-10 diagnosis codes into a single fixed-width string.
    -- Each code is left-justified in its slot and followed by a '*<indicator>*'
    -- delimiter ('*A*') when populated, or '* *' when the slot is empty. Extract
    -- the code (capture group 1) preceding the Nth populated delimiter; empty
    -- slots and unfilled positions yield NULL.
    {% for i in range(1, 26) -%}
    cast(regexp_substr(diagnosis_codes_raw, '([A-Z0-9]+)\\s*\\*[^*\\s]\\*', 1, {{ i }}, 'e', 1) as {{ dbt.type_string() }}) as icd_diag{{ i }}_cd,
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
    null as s3_path,
    file_group_id as filename,
    cast('EDPS' as {{ dbt.type_string() }}) as data_source
from source