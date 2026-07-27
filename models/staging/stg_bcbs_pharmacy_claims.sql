-- Staging model for BCBS pharmacy claims
-- Pulls raw columns from commercial_pharmacy_claims with type casts only
-- Renaming and null placeholders are handled in the intermediate layer

select
    cast(null as {{ dbt.type_string() }}) as int_clm_num,
    cast(null as {{ dbt.type_string() }}) as cursubid,
    cast(null as {{ dbt.type_string() }}) as bcmbrnbr,
    cast('BCBS' as {{ dbt.type_string() }}) as payer,
    null as market,
    null as lob,
    cast(null as {{ dbt.type_string() }}) as clm_pdea_npi,
    cast(null as {{ dbt.type_string() }}) as pharm_npi,
    cast(null as date) as svcdt,
    cast(null as {{ dbt.type_string() }}) as clm_ndc,
    cast(null as {{ dbt.type_string() }}) as metric_quantity,
    cast(null as {{ dbt.type_string() }}) as days_supply,
    cast(null as {{ dbt.type_string() }}) as num_refills,
    cast(null as date) as pddate,
    cast(null as {{ dbt.type_string() }}) as charge_amt,
    cast(null as {{ dbt.type_string() }}) as netpay,
    cast(null as {{ dbt.type_string() }}) as paid,
    cast(null as {{ dbt.type_string() }}) as coins_amt,
    cast(null as {{ dbt.type_string() }}) as copay_amt,
    cast(null as {{ dbt.type_string() }}) as deduct_amt,
    cast(null as {{ dbt.type_string() }}) as rx_curr_clm_ind,
    current_date as date_id,
    null as _run_time,
    null as s3_path,
    null as filename
limit 0