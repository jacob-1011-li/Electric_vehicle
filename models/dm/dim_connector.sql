{{ config(materialized='table') }}

with connector_source as (

    select *

    from {{ ref('int_charging_connectors_disassembly') }}

),

station_tla as (

    select
        station_id,
        station_global_id,
        tla_name_key

    from {{ ref('int_charging_stations_tla') }}

),

final as (

    select
        md5(
            to_varchar(connector_source.connector_config_id)
        ) as connector_key,

        connector_source.*,

        station_tla.station_global_id,
        station_tla.tla_name_key

    from connector_source

    left join station_tla
        on connector_source.station_id = station_tla.station_id

)

select *

from final
