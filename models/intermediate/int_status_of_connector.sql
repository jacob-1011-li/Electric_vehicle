with station as (
    select 
        connector_config_id,
        first_operational_month,
        connector_count,
        connector_status

    from {{ ref ('int_charging_connectors_disassembly')}}
),

status_of_connectors as (
    select
        connector_config_id,
        first_operational_month,

        case 
            when upper(trim(connector_status)) = 'OPERATIVE' 
                then 1
            else 0
        end as active_connector,

        case
            when upper(trim(connector_status)) = 'INOPERATIVE'
                then 1
            else 0
        end as negative_connector,

        case 
            when upper(trim(connector_status)) = 'UNKNOWN'
                then 1
            else 0
        end as unknown_status

        from station 
    )

select *
from status_of_connectors
