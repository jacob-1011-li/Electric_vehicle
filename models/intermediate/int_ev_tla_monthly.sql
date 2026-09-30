{{ config(materialized='view') }}

/*
    Model grain: one row per TLA and analysis month.

    Purpose:
    - keep BEV and PHEV as separate counts;
    - apply the PHEV charging-demand factor;
    - calculate the estimated monthly charger-side demand; and
    - calculate month-end cumulative vehicle counts and demand.

    This is an assumption-based demand estimate. It is not actual charging
    transaction data.
*/
with source_vehicles as (

    select
        vehicle_id,
        upper(trim(district_name)) as tla_name,
        upper(trim(motive_power)) as motive_power,
        first_registration_month_date
    from {{ ref('stg_vehicle_register') }}

), target_ev as (

    select
        vehicle_id,
        tla_name,
        first_registration_month_date,

        case
            when motive_power = 'ELECTRIC' then 'BEV'
            when motive_power = 'PLUGIN PETROL HYBRID' then 'PHEV'
        end as ev_type
    from source_vehicles
    where motive_power in ('ELECTRIC', 'PLUGIN PETROL HYBRID')
      and tla_name is not null
      and first_registration_month_date is not null

), assumptions as (

    select
        {{ var('bev_battery_capacity_kwh', 61.3) }}::number(10, 2)
            as bev_battery_capacity_kwh,
        {{ var('phev_capacity_factor', 0.5) }}::number(10, 4)
            as phev_capacity_factor,
        {{ var('monthly_distance_km', 800) }}::number(10, 2)
            as monthly_distance_km,
        {{ var('range_per_charge_km', 400) }}::number(10, 2)
            as range_per_charge_km,
        {{ var('charging_efficiency', 0.90) }}::number(10, 4)
            as charging_efficiency,
        {{ var('public_charging_share', 1.0) }}::number(10, 4)
            as public_charging_share

), vehicle_demand as (

    select
        target_ev.vehicle_id,
        target_ev.tla_name,
        target_ev.first_registration_month_date,
        target_ev.ev_type,

        case
            when target_ev.ev_type = 'PHEV'
                then assumptions.bev_battery_capacity_kwh
                     * assumptions.phev_capacity_factor
            else assumptions.bev_battery_capacity_kwh
        end as assumed_battery_capacity_kwh,

        assumptions.monthly_distance_km
            / nullif(assumptions.range_per_charge_km, 0)
            as equivalent_full_charges_per_month,

        case
            when target_ev.ev_type = 'PHEV'
                then assumptions.phev_capacity_factor
            else 1.0
        end as charging_demand_factor,

        assumptions.charging_efficiency,
        assumptions.public_charging_share
    from target_ev
    cross join assumptions

), vehicle_monthly_demand as (

    select
        vehicle_id,
        tla_name,
        first_registration_month_date,
        ev_type,
        charging_demand_factor,

        /*
            Battery-side demand:
            61.3 kWh × (800 km / 400 km) = 122.6 kWh for a BEV.
        */
        assumed_battery_capacity_kwh
            * equivalent_full_charges_per_month
            as battery_side_monthly_demand_kwh,

        /*
            Charger-side demand:
            battery-side demand ÷ 90% charging efficiency.

            public_charging_share is 1.0 under the current project
            assumption, so all estimated demand is assigned to public
            chargers.
        */
        assumed_battery_capacity_kwh
            * equivalent_full_charges_per_month
            / nullif(charging_efficiency, 0)
            * public_charging_share
            as charger_side_monthly_demand_kwh
    from vehicle_demand

), date_bounds as (

    select
        greatest(
            (
                select min(first_operational_month)
                from {{ ref('stg_charging_stations') }}
            ),
            (
                select min(first_registration_month_date)
                from {{ ref('stg_vehicle_register') }}
            )
        )::date as start_month,

        least(
            (
                select max(first_operational_month)
                from {{ ref('stg_charging_stations') }}
            ),
            (
                select max(first_registration_month_date)
                from {{ ref('stg_vehicle_register') }}
            )
        )::date as end_month

), generated_months as (

    select
        dateadd(month, seq4(), date_bounds.start_month)::date as month_date,
        date_bounds.end_month
    from date_bounds,
         table(generator(rowcount => 240))

), analysis_months as (

    select month_date
    from generated_months
    where month_date <= end_month

), tla_list as (

    select distinct tla_name
    from vehicle_monthly_demand

), tla_month_scaffold as (

    select
        tla_list.tla_name,
        analysis_months.month_date
    from tla_list
    cross join analysis_months

), aggregated as (

    select
        tla_month_scaffold.tla_name,
        tla_month_scaffold.month_date,

        sum(
            case
                when vehicle_monthly_demand.first_registration_month_date
                     = tla_month_scaffold.month_date
                    and vehicle_monthly_demand.ev_type = 'BEV'
                    then 1
                else 0
            end
        )::integer as new_bev_count,

        sum(
            case
                when vehicle_monthly_demand.first_registration_month_date
                     = tla_month_scaffold.month_date
                    and vehicle_monthly_demand.ev_type = 'PHEV'
                    then 1
                else 0
            end
        )::integer as new_phev_count,

        sum(
            case
                when vehicle_monthly_demand.ev_type = 'BEV'
                    then 1
                else 0
            end
        )::integer as cumulative_bev_count,

        sum(
            case
                when vehicle_monthly_demand.ev_type = 'PHEV'
                    then 1
                else 0
            end
        )::integer as cumulative_phev_count,

        sum(
            case
                when vehicle_monthly_demand.first_registration_month_date
                     = tla_month_scaffold.month_date
                    then vehicle_monthly_demand.charger_side_monthly_demand_kwh
                else 0
            end
        )::number(24, 2) as new_ev_demand_kwh,

        coalesce(
            sum(
                vehicle_monthly_demand.charger_side_monthly_demand_kwh
            ),
            0
        )::number(24, 2) as estimated_ev_demand_kwh

    from tla_month_scaffold
    left join vehicle_monthly_demand
        on vehicle_monthly_demand.tla_name = tla_month_scaffold.tla_name
       and vehicle_monthly_demand.first_registration_month_date
           <= tla_month_scaffold.month_date
    group by
        tla_month_scaffold.tla_name,
        tla_month_scaffold.month_date

)

select
    tla_name,
    month_date,
    new_bev_count,
    new_phev_count,
    cumulative_bev_count,
    cumulative_phev_count,

    cumulative_bev_count
        + cumulative_phev_count
          * {{ var('phev_capacity_factor', 0.5) }}
        as cumulative_bev_equivalent_count,

    new_ev_demand_kwh,
    estimated_ev_demand_kwh,

    {{ var('bev_battery_capacity_kwh', 61.3) }}::number(10, 2)
        as assumed_bev_battery_capacity_kwh,
    {{ var('phev_capacity_factor', 0.5) }}::number(10, 4)
        as assumed_phev_capacity_factor,
    {{ var('monthly_distance_km', 800) }}::number(10, 2)
        as assumed_monthly_distance_km,
    {{ var('range_per_charge_km', 400) }}::number(10, 2)
        as assumed_range_per_charge_km,
    {{ var('charging_efficiency', 0.90) }}::number(10, 4)
        as assumed_charging_efficiency,
    {{ var('public_charging_share', 1.0) }}::number(10, 4)
        as assumed_public_charging_share

from aggregated
order by
    tla_name asc,
    month_date asc