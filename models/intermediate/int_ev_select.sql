with vehicle as (
    select
        *
    from {{ ref ('stg_vehicle_register') }}

),

filter_ev as (

    select
        vehicle_id,
        district_name as tla_name,
        first_registration_month_date,
        motive_power,
        case
            when motive_power = 'ELECTRIC'
                then 'BEV' -- Battery Electric Vehicle
            when motive_power = 'PLUGIN PETROL HYBRID'
                then 'PHEV' -- Plug-in Hybrid Electric Vehicle
        end as ev_type,

        vehicle_make,
        vehicle_model,
        vehicle_type,
        vehicle_usage

    from vehicle

    where motive_power in (
        'ELECTRIC',
        'PLUGIN PETROL HYBRID'
    )
)

select *
from filter_ev
-- order by 
--    first_registration_month_date asc