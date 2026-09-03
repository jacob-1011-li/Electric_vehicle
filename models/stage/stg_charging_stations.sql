with source_data as (

    select *
    from {{ source('nz_public_data', 'charging_station') }}

),

renamed_and_casted as (

    select 
        try_to_number(
            source_data.STATION_COLS:"OBJECTID"::string
        ):: integer as station_ID,

-- Using 'try' is safer than directly use to_decimal, because in 'try' the 
-- unsuccessful transformation will return a null rather than an error. 
        try_to_decimal(
            nullif(
                trim(source_data.STATION_COLS:"latitude"::string
            ), ''),
            10,
            6
        ) as latitude,

        try_to_decimal(
            nullif(
                trim(source_data.STATION_COLS:"longitude"::string
                ), ''),
            10,
            6
        ) as longitude,

        try_to_date(
            nullif(
                trim(source_data.STATION_COLS:"dateFirstOperational"::string
            ), ''),
            'DD/MM/YYYY'
            ) as first_operation_date,
        
        nullif(
            trim(source_data.STATION_COLS:"NAME"::string
                ), 
                ''
            ) as station_name,

        nullif(
            trim(source_data.STATION_COLS:"OPERATOR":: string
                ),
                ''
            ) as station_operator,

        nullif(
            trim(source_data.STATION_COLS:"OWNER":: string
                ),
                ''
        ) as station_owner,

        nullif(
            trim(source_data.STATION_COLS:"ADDRESS":: string
            ),
            ''
        ) as station_address,

        try_to_boolean(
            nullif(
                trim(source_data.STATION_COLS:"is24Hours":: string
                ),
                ''
            )
        ) as station_is24Hours,

        try_to_number(
            nullif(
                trim(source_data.STATION_COLS:"carParkCount"
                ),
                ''
            )::integer
        ) as station_carParkCount,

        try_to_boolean(
            nullif(
                trim(source_data.STATION_COLS:"hasCarparkCost"
            ),
            ''
            )
        ) as staion_hasCarparkCost,

        nullif(
            trim(source_data.STATION_COLS:"maxTimeLimit"
            ),
            ''
        ) as station_maxTimeLimit,

        try_to_boolean(
            nullif(
                trim(source_data.STATION_COLS:"hasTouristAttraction"
                ),
                ''
            )
        ) as station_hasTouristAttraction,

        nullif(
            trim(source_data.STATION_COLS:"hasChargingCost"::string
            ),
            ''
        ) as station_hasChargingCost,

        upper(
            trim(source_data.STATION_COLS:"GlobalID"::string
        )) as station_global_ID,

        try_to_number(
        source_data.STATION_COLS:"numberOfConnectors"::string
        )::integer as connector_count,
        
        nullif(
            trim(source_data.STATION_COLS:"connectorsList"::string),
            ''
        ) as connector_list_raw

    from source_data

)

select 
    *,
    date_trunc(
        'month',
        first_operation_date
     ) as first_operational_month,

-- from snowflake st_makepoint(x,y), the format should be st_makepoint(longitude, latitude)
     case 
        when r.latitude between -90 and 90
        and r.longitude between -180 and 180
        then st_makepoint(
            r.longitude,
            r.latitude
        )
        else null
    end as station_geography

from renamed_and_casted as r
