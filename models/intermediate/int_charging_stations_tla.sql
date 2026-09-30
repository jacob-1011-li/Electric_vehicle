with charging_stations as (
    select 
        station_id,
        station_global_id,
        station_geography

    from {{ ref('stg_charging_stations') }}        

),

tla_boundaries as (

    select
        tla_code,
        tla_name,
        tla_name_ascii,
        tla_name_key,
        boundary_year,
        boundary_wkt,
        tla_geography
    from {{ ref('stg_tla_boundaries' )}}
    where is_valid_tla_geography = true 

)

select
    s.station_id,
    s.station_global_id,
    s.station_geography,

    t.tla_code,
    t.tla_name,
    t.tla_name_ascii,
    t.tla_name_key,
    t.boundary_year,

    case 
        when t.tla_code is not null then 'MATCHED'
        else 'UNMATCHED'
    end as mapping_status

from charging_stations as s

left join tla_boundaries as t
    on st_covers( -- st_covers() is a function in snowflake which is used to determine a point in a geography area.
        t.tla_geography,
        s.station_geography
    )