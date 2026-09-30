with connector_base as (

    select
        c.connector_config_id,
        c.station_id,

        try_to_number(c.power_kw)::number(10, 2) as power_kw,

        upper(trim(c.connector_status)) as connector_status,

        s.first_operational_month,

        coalesce(t.tla_name, 'UNMATCHED') as tla_name

    from {{ ref('int_charging_connectors_disassembly') }} as c

    left join {{ ref('stg_charging_stations') }} as s
        on c.station_id = s.station_id

    left join {{ ref('int_charging_stations_tla') }} as t
        on c.station_id = t.station_id

),

connector_monthly as (

    select
        m.month_date,
        m.day_in_month,

        c.tla_name,
        c.station_id,
        c.connector_config_id,
        c.power_kw,
        c.connector_status,

        case
            when c.connector_status = 'OPERATIVE'
                then 1
            else 0
        end as active_connector_flag,

        case
            when c.connector_status = 'OPERATIVE'
                then c.power_kw * 8 * m.day_in_month
            else 0
        end as theoretical_output_kwh

    from connector_base as c

    inner join {{ ref('int_month_spine') }} as m
        on c.first_operational_month <= m.month_date

),

regional_monthly as (

    select
        month_date,
        tla_name,

        count(distinct station_id) as station_count,

        sum(active_connector_flag) as active_connector_count,

        sum(theoretical_output_kwh)
            as monthly_theoretical_output_kwh

    from connector_monthly

    group by
        month_date,
        tla_name

)

select
    month_date,
    tla_name,
    station_count,
    active_connector_count,
    monthly_theoretical_output_kwh

from regional_monthly

order by
    tla_name asc,
    month_date asc