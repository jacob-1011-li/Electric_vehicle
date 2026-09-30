with stations as (
    select
        *
    from {{ ref('int_charging_stations_tla') }})

select 
    * 
from stations
where mapping_status = 'MATCHED'