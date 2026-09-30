{{ config(materialized='table') }}

with source_ev as (

    select
        vehicle_id,
        upper(trim(tla_name)) as tla_name,
        first_registration_month_date,
        upper(trim(ev_type)) as ev_type

    from {{ ref('int_ev_select') }}

    where vehicle_id is not null

),

assumptions as (

    select
        {{ var('bev_battery_capacity_kwh', 61.3) }}::number(10, 2)
            as assumed_bev_battery_capacity_kwh,

        {{ var('phev_capacity_factor', 0.5) }}::number(10, 4)
            as assumed_phev_capacity_factor,

        {{ var('monthly_distance_km', 800) }}::number(10, 2)
            as assumed_monthly_distance_km,

        {{ var('range_per_charge_km', 400) }}::number(10, 2)
            as assumed_range_per_charge_km

),

final as (

    select
        source_ev.vehicle_id,
        source_ev.ev_type,
        source_ev.tla_name,
        source_ev.first_registration_month_date,

        year(source_ev.first_registration_month_date)
            as first_registration_year,

        month(source_ev.first_registration_month_date)
            as first_registration_month,

        assumptions.assumed_bev_battery_capacity_kwh,
        assumptions.assumed_phev_capacity_factor,
        assumptions.assumed_monthly_distance_km,
        assumptions.assumed_range_per_charge_km,

        case
            when source_ev.ev_type = 'PHEV'
                then assumptions.assumed_phev_capacity_factor
            else 1.0
        end::number(10, 4) as vehicle_capacity_factor,

        case
            when source_ev.ev_type = 'PHEV'
                then assumptions.assumed_bev_battery_capacity_kwh
                     * assumptions.assumed_phev_capacity_factor
            else assumptions.assumed_bev_battery_capacity_kwh
        end::number(10, 2) as assumed_battery_capacity_kwh

    from source_ev

    cross join assumptions

)

select
    vehicle_id,
    ev_type,
    tla_name,
    first_registration_month_date,
    first_registration_year,
    first_registration_month,
    assumed_bev_battery_capacity_kwh,
    assumed_phev_capacity_factor,
    assumed_monthly_distance_km,
    assumed_range_per_charge_km,
    vehicle_capacity_factor,
    assumed_battery_capacity_kwh

from final