with month_source as(
    select 
        *
    from {{ref('dim_month')}}
),

rate_source as(
    select
        *
    from {{ref('int_rate_between_ev_input_and_connector_output')}}
),

tla_source as (
    select
        *
    from {{ref('stg_tla_boundaries')}}
),

combined as(
    select 
        r.rate_sk,
        r.tla_name,
        r.month_date,
        r.connector_output_to_ev_input_rate,
        t.tla_name,
        m.month_date

    from rate_source as r

    left join tla_source as t
        on r.tla_name = t.tla_name_key 

    left join month_source as m
        on r.month_date = m.month_date
)

select *
from combined
order by 
    connector_output_to_ev_input_rate desc nulls last
-- Because when calculate connector_output_to_ev_input_rate column, there envolves a null value case.