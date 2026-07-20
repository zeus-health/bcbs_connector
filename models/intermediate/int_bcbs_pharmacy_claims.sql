-- Intermediate BCBS pharmacy claims: normalize and dedupe by claim id (prefer CURR_CLM_IND='Y')
-- Payer, market, and LOB are hard-coded per DE-3263 (raw_data metadata is incorrect)
-- Column renaming from raw names to Tuva shape happens here (not in staging)
-- Like eligibility, pharmacy files are cumulative — only use the latest snapshot file.
-- Claims with both positive and negative amounts (reversals) cancel out and are excluded.

with latest_snapshot as (
  select *
  from {{ ref('stg_bcbs_pharmacy_claims') }}
  where date_id = (select max(date_id) from {{ ref('stg_bcbs_pharmacy_claims') }})
),

-- Claims that have both positive and negative amounts cancel out (reversals)
cancelled_claims as (
  select int_clm_num
  from latest_snapshot
  group by int_clm_num
  having min(try_cast(paid as double)) < 0 and max(try_cast(paid as double)) > 0
),

ranked as (
  select
    s.int_clm_num,
    concat(s.cursubid, s.bcmbrnbr) as indiv_entpr_id,
    s.payer,
    s.market,
    s.lob,
    s.clm_pdea_npi,
    s.pharm_npi,
    s.svcdt,
    s.clm_ndc,
    s.metric_quantity,
    s.days_supply,
    s.num_refills,
    s.pddate,
    s.charge_amt,
    s.netpay,
    s.paid,
    s.coins_amt,
    s.copay_amt,
    s.deduct_amt,
    s.rx_curr_clm_ind,
    s.date_id,
    s._run_time,
    s.s3_path,
    s.filename,
    row_number() over (
      partition by s.int_clm_num
      order by case when upper(coalesce(s.rx_curr_clm_ind, '')) = 'Y' then 1 else 2 end, s.date_id desc, s._run_time desc
    ) as rn
  from latest_snapshot s
  where s.int_clm_num not in (select int_clm_num from cancelled_claims)
)

select
  cast(int_clm_num as {{ dbt.type_string() }}) as claim_id,
  cast(row_number() over (
    partition by int_clm_num
    order by svcdt, clm_ndc
  ) as {{ dbt.type_int() }}) as claim_line_number,
  cast(concat('bcbs', '|', 'MA', '|', 'COMM', '.', indiv_entpr_id) as {{ dbt.type_string() }}) as person_id,
  cast(indiv_entpr_id as {{ dbt.type_string() }}) as member_id,
  cast('bcbs' as {{ dbt.type_string() }}) as payer,
  cast('COMM' as {{ dbt.type_string() }}) as payer_type,
  cast(lob as {{ dbt.type_string() }}) as plan,
  {{ validate_npi('clm_pdea_npi') }} as prescribing_provider_npi,
  cast(pharm_npi as {{ dbt.type_string() }}) as dispensing_provider_npi,
  cast(svcdt as date) as dispensing_date,
  cast(clm_ndc as {{ dbt.type_string() }}) as ndc_code,
  cast(try_cast(metric_quantity as double) as {{ dbt.type_int() }}) as quantity,
  cast(try_cast(days_supply as double) as {{ dbt.type_int() }}) as days_supply,
  cast(try_cast(num_refills as int) as {{ dbt.type_int() }}) as refills,
  cast(pddate as date) as paid_date,
  try_cast(netpay as double) as paid_amount,
  try_cast(paid as double) as allowed_amount,
  try_cast(charge_amt as double) as charge_amount,
  try_cast(coins_amt as double) as coinsurance_amount,
  try_cast(copay_amt as double) as copayment_amount,
  try_cast(deduct_amt as double) as deductible_amount,
  cast(null as {{ dbt.type_int() }}) as in_network_flag,
  cast('bcbs|MA|COMM' as {{ dbt.type_string() }}) as data_source,
  cast(s3_path as {{ dbt.type_string() }}) as file_name,
  cast(date_id as date) as file_date,
  cast(_run_time as {{ dbt.type_timestamp() }}) as ingest_datetime
from ranked
where rn = 1
  and clm_ndc is not null
