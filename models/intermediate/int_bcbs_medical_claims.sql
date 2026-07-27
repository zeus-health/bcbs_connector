-- Intermediate BCBS medical claims: classify, compute span, and dedupe by claim+line (prefer CURR_CLM_IND='Y')
-- Payer, market, and LOB are hard-coded per DE-3263 (raw_data metadata is incorrect)
-- Column renaming from raw names to Tuva shape happens here (not in staging)
-- Like eligibility, medical claims files are cumulative — only use the latest snapshot file.
-- Claims with both positive and negative amounts (reversals) cancel out and are excluded.

with latest_snapshot as (
  select *
  from {{ ref('stg_bcbs_medical_claims') }}
  where date_id = (select max(date_id) from {{ ref('stg_bcbs_medical_claims') }})
),

-- Claims that have both positive and negative amounts cancel out (reversals)
cancelled_claims as (
  select int_clm_num, clm_line_num
  from latest_snapshot
  group by int_clm_num, clm_line_num
  having min(try_cast(paid as double)) < 0 and max(try_cast(paid as double)) > 0
),

ranked as (
  select
    s.int_clm_num,
    s.clm_line_num,
    s.revenue_cd,
    s.cms_place_srv_cd,
    concat(s.cursubid, s.bcmbrnbr) as indiv_entpr_id,
    s.payer,
    s.market,
    s.lob,
    s.svcdt,
    s.admitdt,
    s.dischdt,
    s.admit_source_cd,
    s.type_admit_cd,
    s.disch_stat_cd,
    s.bill_type_cd,
    s.drg_cd,
    coalesce(s.srv_units, s.dw_srv_units) as derv_su_cnt,
    coalesce(s.hcpcs_proc_cd, s.cpt_proc_cd) as proc_cd,
    s.cpt_pmod1_cd,
    s.cpt_pmod2_cd,
    s.cpt_pmod3_cd,
    s.sprovnpi,
    s.bprovnpi,
    s.pddate,
    s.charge_amt,
    s.netpay,
    s.paid,
    s.coins_amt,
    s.copay_amt,
    s.deduct_amt,
    s.dw_mem_liab_amt,
    s.cobamt,
    s.icd_subm_ind,
    s.icd_diag1_cd,
    s.icd_diag2_cd,
    s.icd_diag3_cd,
    s.icd_diag4_cd,
    s.icd_diag5_cd,
    s.icd_diag6_cd,
    s.icd_diag7_cd,
    s.icd_diag8_cd,
    s.icd_diag9_cd,
    s.icd_diag10_cd,
    s.icd_proc1_cd,
    s.icd_proc2_cd,
    s.icd_proc3_cd,
    s.icd_proc4_cd,
    s.icd_proc5_cd,
    s.dw_netwk_ind,
    s.curr_clm_ind,
    s.date_id,
    s._run_time,
    s.s3_path,
    s.filename,
    min(case when upper(coalesce(s.curr_clm_ind, '')) = 'Y' then s.svcdt end) over (
      partition by s.int_clm_num
    ) as claim_start_date,
    max(case when upper(coalesce(s.curr_clm_ind, '')) = 'Y' then s.svcdt end) over (
      partition by s.int_clm_num
    ) as claim_end_date,
    row_number() over (
      partition by s.int_clm_num, s.clm_line_num
      order by case when upper(coalesce(s.curr_clm_ind, '')) = 'Y' then 1 else 2 end, s.date_id desc, s._run_time desc
    ) as rn
  from latest_snapshot s
  where not exists (
    select 1 from cancelled_claims c
    where c.int_clm_num = s.int_clm_num and c.clm_line_num = s.clm_line_num
  )
),

claim_types as (
  select
    s.int_clm_num,
    case
      when max(case when s.bill_type_cd is not null and trim(s.bill_type_cd) != '' then 1 else 0 end) = 1
        then 'institutional'
      when max(case when s.cms_place_srv_cd is not null and trim(s.cms_place_srv_cd) != '' then 1 else 0 end) = 1
        then 'professional'
      else 'undetermined'
    end as claim_type
  from latest_snapshot s
  where not exists (
    select 1 from cancelled_claims c
    where c.int_clm_num = s.int_clm_num
  )
  group by s.int_clm_num
)

select
  cast(r.int_clm_num as {{ dbt.type_string() }}) as claim_id,
  cast(r.clm_line_num as {{ dbt.type_int() }}) as claim_line_number,
  cast(ct.claim_type as {{ dbt.type_string() }}) as claim_type,
  cast(concat('bcbs', '|', 'MA', '|', 'COMM', '.', r.indiv_entpr_id) as {{ dbt.type_string() }}) as person_id,
  cast(r.indiv_entpr_id as {{ dbt.type_string() }}) as member_id,
  cast('bcbs' as {{ dbt.type_string() }}) as payer,
  -- HACK: Payer type is null so CMS HCC flows through since currently it only allows medicare + null payer types
  cast(null as {{ dbt.type_string() }}) as payer_type,
  cast(r.lob as {{ dbt.type_string() }}) as plan,
  coalesce(cast(r.claim_start_date as date), cast(r.svcdt as date)) as claim_start_date,
  coalesce(cast(r.claim_end_date as date), cast(r.svcdt as date)) as claim_end_date,
  cast(r.svcdt as date) as claim_line_start_date,
  cast(null as date) as claim_line_end_date,
  cast(r.admitdt as date) as admission_date,
  cast(r.dischdt as date) as discharge_date,
  cast(r.admit_source_cd as {{ dbt.type_string() }}) as admit_source_code,
  cast(r.type_admit_cd as {{ dbt.type_string() }}) as admit_type_code,
  cast(r.disch_stat_cd as {{ dbt.type_string() }}) as discharge_disposition_code,
  cast(r.cms_place_srv_cd as {{ dbt.type_string() }}) as place_of_service_code,
  cast(r.bill_type_cd as {{ dbt.type_string() }}) as bill_type_code,
  cast(case when r.drg_cd is not null then 'ms-drg' else null end as {{ dbt.type_string() }}) as drg_code_type,
  cast(r.drg_cd as {{ dbt.type_string() }}) as drg_code,
  cast(case
    when r.revenue_cd is null or r.revenue_cd = '*' then null
    when length(r.revenue_cd) = 3 then concat('0', r.revenue_cd)
    else r.revenue_cd
  end as {{ dbt.type_string() }}) as revenue_center_code,
  try_cast(r.derv_su_cnt as double) as service_unit_quantity,
  cast(case when r.proc_cd = '*' then null else r.proc_cd end as {{ dbt.type_string() }}) as hcpcs_code,
  cast(r.cpt_pmod1_cd as {{ dbt.type_string() }}) as hcpcs_modifier_1,
  cast(r.cpt_pmod2_cd as {{ dbt.type_string() }}) as hcpcs_modifier_2,
  cast(r.cpt_pmod3_cd as {{ dbt.type_string() }}) as hcpcs_modifier_3,
  cast(null as {{ dbt.type_string() }}) as hcpcs_modifier_4,
  cast(null as {{ dbt.type_string() }}) as hcpcs_modifier_5,
  {{ validate_npi('r.sprovnpi') }} as rendering_npi,
  cast(null as {{ dbt.type_string() }}) as rendering_tin,
  {{ validate_npi('r.bprovnpi') }} as billing_npi,
  cast(null as {{ dbt.type_string() }}) as billing_tin,
  cast(null as {{ dbt.type_string() }}) as facility_npi,
  cast(r.pddate as date) as paid_date,
  try_cast(r.charge_amt as double) as charge_amount,
  try_cast(r.paid as double) as allowed_amount,
  try_cast(r.netpay as double) as paid_amount,
  try_cast(r.coins_amt as double) as coinsurance_amount,
  try_cast(r.copay_amt as double) as copayment_amount,
  try_cast(r.deduct_amt as double) as deductible_amount,
  try_cast(r.dw_mem_liab_amt as double) + try_cast(r.netpay as double) + try_cast(r.cobamt as double) as total_cost_amount,
  cast(case
    when r.icd_subm_ind = '10' then 'icd-10-cm'
    when r.icd_subm_ind = '9' then 'icd-9-cm'
    else null
  end as {{ dbt.type_string() }}) as diagnosis_code_type,
  cast(r.icd_diag1_cd as {{ dbt.type_string() }}) as diagnosis_code_1,
  cast(r.icd_diag2_cd as {{ dbt.type_string() }}) as diagnosis_code_2,
  cast(r.icd_diag3_cd as {{ dbt.type_string() }}) as diagnosis_code_3,
  cast(r.icd_diag4_cd as {{ dbt.type_string() }}) as diagnosis_code_4,
  cast(r.icd_diag5_cd as {{ dbt.type_string() }}) as diagnosis_code_5,
  cast(r.icd_diag6_cd as {{ dbt.type_string() }}) as diagnosis_code_6,
  cast(r.icd_diag7_cd as {{ dbt.type_string() }}) as diagnosis_code_7,
  cast(r.icd_diag8_cd as {{ dbt.type_string() }}) as diagnosis_code_8,
  cast(r.icd_diag9_cd as {{ dbt.type_string() }}) as diagnosis_code_9,
  cast(r.icd_diag10_cd as {{ dbt.type_string() }}) as diagnosis_code_10,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_11,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_12,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_13,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_14,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_15,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_16,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_17,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_18,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_19,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_20,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_21,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_22,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_23,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_24,
  cast(null as {{ dbt.type_string() }}) as diagnosis_code_25,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_1,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_2,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_3,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_4,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_5,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_6,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_7,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_8,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_9,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_10,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_11,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_12,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_13,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_14,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_15,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_16,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_17,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_18,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_19,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_20,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_21,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_22,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_23,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_24,
  cast(null as {{ dbt.type_string() }}) as diagnosis_poa_25,
  cast(case
    when r.icd_proc1_cd is not null then 'icd-10-pcs'
    else null
  end as {{ dbt.type_string() }}) as procedure_code_type,
  cast(r.icd_proc1_cd as {{ dbt.type_string() }}) as procedure_code_1,
  cast(r.icd_proc2_cd as {{ dbt.type_string() }}) as procedure_code_2,
  cast(r.icd_proc3_cd as {{ dbt.type_string() }}) as procedure_code_3,
  cast(r.icd_proc4_cd as {{ dbt.type_string() }}) as procedure_code_4,
  cast(r.icd_proc5_cd as {{ dbt.type_string() }}) as procedure_code_5,
  cast(null as {{ dbt.type_string() }}) as procedure_code_6,
  cast(null as {{ dbt.type_string() }}) as procedure_code_7,
  cast(null as {{ dbt.type_string() }}) as procedure_code_8,
  cast(null as {{ dbt.type_string() }}) as procedure_code_9,
  cast(null as {{ dbt.type_string() }}) as procedure_code_10,
  cast(null as {{ dbt.type_string() }}) as procedure_code_11,
  cast(null as {{ dbt.type_string() }}) as procedure_code_12,
  cast(null as {{ dbt.type_string() }}) as procedure_code_13,
  cast(null as {{ dbt.type_string() }}) as procedure_code_14,
  cast(null as {{ dbt.type_string() }}) as procedure_code_15,
  cast(null as {{ dbt.type_string() }}) as procedure_code_16,
  cast(null as {{ dbt.type_string() }}) as procedure_code_17,
  cast(null as {{ dbt.type_string() }}) as procedure_code_18,
  cast(null as {{ dbt.type_string() }}) as procedure_code_19,
  cast(null as {{ dbt.type_string() }}) as procedure_code_20,
  cast(null as {{ dbt.type_string() }}) as procedure_code_21,
  cast(null as {{ dbt.type_string() }}) as procedure_code_22,
  cast(null as {{ dbt.type_string() }}) as procedure_code_23,
  cast(null as {{ dbt.type_string() }}) as procedure_code_24,
  cast(null as {{ dbt.type_string() }}) as procedure_code_25,
  cast(null as date) as procedure_date_1,
  cast(null as date) as procedure_date_2,
  cast(null as date) as procedure_date_3,
  cast(null as date) as procedure_date_4,
  cast(null as date) as procedure_date_5,
  cast(null as date) as procedure_date_6,
  cast(null as date) as procedure_date_7,
  cast(null as date) as procedure_date_8,
  cast(null as date) as procedure_date_9,
  cast(null as date) as procedure_date_10,
  cast(null as date) as procedure_date_11,
  cast(null as date) as procedure_date_12,
  cast(null as date) as procedure_date_13,
  cast(null as date) as procedure_date_14,
  cast(null as date) as procedure_date_15,
  cast(null as date) as procedure_date_16,
  cast(null as date) as procedure_date_17,
  cast(null as date) as procedure_date_18,
  cast(null as date) as procedure_date_19,
  cast(null as date) as procedure_date_20,
  cast(null as date) as procedure_date_21,
  cast(null as date) as procedure_date_22,
  cast(null as date) as procedure_date_23,
  cast(null as date) as procedure_date_24,
  cast(null as date) as procedure_date_25,
  cast(case
    when r.dw_netwk_ind = 'Y' then 1
    when r.dw_netwk_ind = 'N' then 0
    else null
  end as {{ dbt.type_int() }}) as in_network_flag,
  cast(null as {{ dbt.type_string() }}) as group_id,
  cast(null as {{ dbt.type_string() }}) as group_name,
  cast('bcbs|MA|COMM' as {{ dbt.type_string() }}) as data_source,
  cast(r.s3_path as {{ dbt.type_string() }}) as file_name,
  cast(r.date_id as date) as file_date,
  cast(r._run_time as {{ dbt.type_timestamp() }}) as ingest_datetime
from ranked r
left join claim_types ct on r.int_clm_num = ct.int_clm_num
where r.rn = 1
  and (r.sprovnpi is null or {{ validate_npi('r.sprovnpi') }} is not null)
  and (r.bprovnpi is null or {{ validate_npi('r.bprovnpi') }} is not null)
