-- Staging model for BCBS pharmacy claims
-- Pulls raw columns from commercial_pharmacy_claims with type casts only
-- Renaming and null placeholders are handled in the intermediate layer

select
    cast(int_clm_num as {{ dbt.type_string() }}) as int_clm_num,
    cast(cursubid as {{ dbt.type_string() }}) as cursubid,
    cast(bcmbrnbr as {{ dbt.type_string() }}) as bcmbrnbr,
    payer,
    market,
    lob,
    cast(clm_pdea_npi as {{ dbt.type_string() }}) as clm_pdea_npi,
    cast(pharm_npi as {{ dbt.type_string() }}) as pharm_npi,
    cast(svcdt as date) as svcdt,
    cast(clm_ndc as {{ dbt.type_string() }}) as clm_ndc,
    cast(metric_quantity as {{ dbt.type_string() }}) as metric_quantity,
    cast(days_supply as {{ dbt.type_string() }}) as days_supply,
    cast(num_refills as {{ dbt.type_string() }}) as num_refills,
    cast(pddate as date) as pddate,
    cast(charge_amt as {{ dbt.type_string() }}) as charge_amt,
    cast(netpay as {{ dbt.type_string() }}) as netpay,
    cast(paid as {{ dbt.type_string() }}) as paid,
    cast(coins_amt as {{ dbt.type_string() }}) as coins_amt,
    cast(copay_amt as {{ dbt.type_string() }}) as copay_amt,
    cast(deduct_amt as {{ dbt.type_string() }}) as deduct_amt,
    cast(rx_curr_clm_ind as {{ dbt.type_string() }}) as rx_curr_clm_ind,
    cast(date_id as date) as date_id,
    _run_time,
    s3_path,
    filename
from {{ source('bcbs', 'commercial_pharmacy_claims') }}
