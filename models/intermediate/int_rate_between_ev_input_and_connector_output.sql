{{ config(materialized='table') }}

/*
    Business process:
        Monthly comparison between estimated EV charging demand and
        theoretical public charging capacity.

    Grain:
        One row per official TLA and analysis month.

    Rate definition:
        connector_output_to_ev_input_rate
            = monthly theoretical connector output kWh
              / estimated EV input demand kWh
*/
with tla_list as (

    select distinct
        upper(trim(tla_name_key)) as tla_name

    from {{ ref('stg_tla_boundaries') }}

    where tla_name_key is not null

),

ev_monthly_source as (

    select
        upper(trim(tla_name)) as tla_name,
        month_date,

        coalesce(
            estimated_ev_demand_kwh,
            0
        )::number(24, 2) as estimated_ev_demand_kwh

    from {{ ref('int_ev_tla_monthly') }}

    where tla_name is not null
      and month_date is not null

),

connector_monthly_source as (

    select
        upper(trim(tla_name)) as tla_name,
        month_date,

        coalesce(
            monthly_theoretical_output_kwh,
            0
        )::number(24, 2) as monthly_theoretical_output_kwh

    from {{ ref('int_count_monthly_output') }}

    where tla_name is not null
      and month_date is not null

),

common_date_range as (

    select
        greatest(
            (
                select min(month_date)
                from ev_monthly_source
            ),
            (
                select min(month_date)
                from connector_monthly_source
            )
        )::date as start_month,

        least(
            (
                select max(month_date)
                from ev_monthly_source
            ),
            (
                select max(month_date)
                from connector_monthly_source
            )
        )::date as end_month

),

analysis_months as (

    select distinct
        month_date

    from (

        select month_date
        from ev_monthly_source

        union all

        select month_date
        from connector_monthly_source

    ) as all_source_months

    cross join common_date_range

    where month_date between start_month and end_month

),

ev_monthly as (

    select
        tla_name,
        month_date,

        sum(estimated_ev_demand_kwh)::number(24, 2)
            as estimated_ev_demand_kwh

    from ev_monthly_source

    group by
        tla_name,
        month_date

),

connector_monthly as (

    select
        tla_name,
        month_date,

        sum(monthly_theoretical_output_kwh)::number(24, 2)
            as monthly_theoretical_output_kwh

    from connector_monthly_source

    group by
        tla_name,
        month_date

),

tla_month_spine as (

    select
        tla_list.tla_name,
        analysis_months.month_date

    from tla_list

    cross join analysis_months

),

combined as (

    select
        tla_month_spine.tla_name,
        tla_month_spine.month_date,

        coalesce(
            ev_monthly.estimated_ev_demand_kwh,
            0
        )::number(24, 2) as estimated_ev_demand_kwh,

        coalesce(
            connector_monthly.monthly_theoretical_output_kwh,
            0
        )::number(24, 2) as monthly_theoretical_output_kwh

    from tla_month_spine

    left join ev_monthly
        on tla_month_spine.tla_name = ev_monthly.tla_name
       and tla_month_spine.month_date = ev_monthly.month_date

    left join connector_monthly
        on tla_month_spine.tla_name = connector_monthly.tla_name
       and tla_month_spine.month_date = connector_monthly.month_date

),

final as (

    select
        md5(
            tla_name
            || '|'
            || to_char(month_date, 'YYYY-MM-DD')
        ) as rate_sk,

        tla_name,
        month_date,
        estimated_ev_demand_kwh,
        monthly_theoretical_output_kwh,

        monthly_theoretical_output_kwh
            - estimated_ev_demand_kwh
            as supply_demand_gap_kwh,

        case
            when estimated_ev_demand_kwh > 0
                then (
                    monthly_theoretical_output_kwh
                    / nullif(estimated_ev_demand_kwh, 0)
                )::number(18, 6)
            else null
        end as connector_output_to_ev_input_rate

    from combined

)

select
    rate_sk,
    tla_name,
    month_date,
    estimated_ev_demand_kwh,
    monthly_theoretical_output_kwh,
    supply_demand_gap_kwh,
    connector_output_to_ev_input_rate

from final
order by
    tla_name,
    month_date