with station as ( -- Define a cte, which named station, just a temporary existed table

    select
        station_id,
        first_operational_month,
        connector_list_raw

    from {{ ref('stg_charging_stations')}} -- ref('stg_charging_stations') comes from Jinja.

    where connector_list_raw is not null -- Only select required data.

), -- as same as select ... as station from ... in sql

connector_elements as (
    select 
        s.station_id,
        s.first_operational_month,

        f.index + 1 as connector_group_number, -- Step 4. Generate a index number and add from 0 to every individual connector (f).

        trim(trim(f.value::string), '{}') as connector_raw -- Step 5. Remove inside ' ' first and then remove the '{}', f.value = information saved in f.

    from station as s, -- step 1.

    lateral flatten( -- Step 3.
        input => split(
            s.connector_list_raw,
            '},{'
        ) -- Step 2. cut connector_list_raw into individual connectors. From ['{A},{B}'] cut into {'{A', 'B}'}
    ) as f -- Identify the result in f, where f comes from
),

parsed_connectors_list as (
    select 

        concat(
            station_id::varchar,
            '-',
            connector_group_number::varchar
        ) as connector_config_id,

        station_id,
        first_operational_month,
        connector_group_number,
        connector_raw,

        -- First element, type
        nullif(
            trim(split_part(connector_raw, ',',1)),
            ''
        ) as current_type,

        --Second element, Power
       try_to_number(
            replace(
             lower(trim(split_part(connector_raw, ',', 2))),
             'kw',
             ''
            )
        ) as power_kw,

        -- Third element, connector type eg. CHAdeMO
        nullif(
            trim(split_part(connector_raw, ',',3)),
            ''
        ) as connector_type,

        -- Fourth element, Status
        upper(
            nullif(
                trim(
                    replace(
                        lower(split_part(connector_raw, ',',4)),
                        'status:',
                        ''
                    )
                ),
                ''
            )
        ) as connector_status,

        -- Fifth element, connector_count, eg. Count:1
        try_to_number(
            replace(
                lower(trim(split_part(connector_raw, ',', 5))),
                'count:',
                ''
                
            )
        ):: integer as connector_count

    from connector_elements
)

select *
from parsed_connectors_list