with source_data as (

    select *
    from {{ source('nz_public_data', 'charging_station') }}

),

renamed_and_casted as (

    select 

        try_to_number(
            source_data.STATION_COLS:"OBJECTID"::string
        )::integer as station_ID,

        try_to_decimal(
            nullif(
                trim(
                    source_data.STATION_COLS:"latitude"::string
                ),
                ''
            ),
            10,
            6
        ) as latitude,

        try_to_decimal(
            nullif(
                trim(
                    source_data.STATION_COLS:"longitude"::string
                ),
                ''
            ),
            10,
            6
        ) as longitude_raw,

        try_to_date(
            nullif(
                trim(
                    source_data.STATION_COLS:"dateFirstOperational"::string
                ),
                ''
            ),
            'DD/MM/YYYY'
        ) as first_operation_date,

        nullif(
            trim(
                source_data.STATION_COLS:"NAME"::string
            ),
            ''
        ) as station_name,

        nullif(
            trim(
                source_data.STATION_COLS:"OPERATOR"::string
            ),
            ''
        ) as station_operator,

        nullif(
            trim(
                source_data.STATION_COLS:"OWNER"::string
            ),
            ''
        ) as station_owner,

        nullif(
            trim(
                source_data.STATION_COLS:"ADDRESS"::string
            ),
            ''
        ) as station_address,

        try_to_boolean(
            nullif(
                trim(
                    source_data.STATION_COLS:"is24Hours"::string
                ),
                ''
            )
        ) as station_is24Hours,

        try_to_number(
            nullif(
                trim(
                    source_data.STATION_COLS:"carParkCount"::string
                ),
                ''
            )
        )::integer as station_carParkCount,

        try_to_boolean(
            nullif(
                trim(
                    source_data.STATION_COLS:"hasCarparkCost"::string
                ),
                ''
            )
        ) as staion_hasCarparkCost,

        nullif(
            trim(
                source_data.STATION_COLS:"maxTimeLimit"::string
            ),
            ''
        ) as station_maxTimeLimit,

        try_to_boolean(
            nullif(
                trim(
                    source_data.STATION_COLS:"hasTouristAttraction"::string
                ),
                ''
            )
        ) as station_hasTouristAttraction,

        try_to_boolean(
            nullif(
                trim(
                    source_data.STATION_COLS:"hasChargingCost"::string
                ),
                ''
            )
        ) as station_hasChargingCost,

        upper(
            trim(
                source_data.STATION_COLS:"GlobalID"::string
            )
        ) as station_global_ID,

        try_to_number(
            source_data.STATION_COLS:"numberOfConnectors"::string
        )::integer as connector_count,

        nullif(
            trim(
                source_data.STATION_COLS:"connectorsList"::string
            ),
            ''
        ) as connector_list_raw

    from source_data

),

corrected_coordinates as (

    select
        r.*,

        case
            when r.station_ID = 160478
                 and r.longitude_raw = 76.088402
                then 176.088402
            else r.longitude_raw
        end as longitude

    from renamed_and_casted as r

)

select
    r.*,

    date_trunc(
        'month',
        r.first_operation_date
    ) as first_operational_month,

    case
        when r.latitude between -90 and 90
         and r.longitude between -180 and 180
        then st_makepoint(
            r.longitude,
            r.latitude
        )
        else null
    end as station_geography

from corrected_coordinates as r