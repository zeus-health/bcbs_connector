-- Combined BCBS medical claims: union of the standard medical claims file and
-- the EDPS (encounter) file. Both staging models emit an identical column
-- contract, so this is a simple union all with no transformation.

select * from {{ ref('stg_bcbs_medical_claims') }}

union all

select * from {{ ref('stg_bcbs_edps_medical_claims') }}
