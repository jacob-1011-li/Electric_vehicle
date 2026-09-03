with source_data as (

    select *
    from {{ source('nz_public_data', 'motor_vehicle_raw') }}

),

renamed_and_casted as (

    select
        try_to_number(OBJECTID) as vehicle_id,

        nullif(upper(trim(TLA)), '') as district_name,

        nullif(upper(trim(MOTIVE_POWER)), '') as motive_power,

        try_to_number(FIRST_NZ_REGISTRATION_YEAR)
            as first_registration_year,

        try_to_number(FIRST_NZ_REGISTRATION_MONTH)
            as first_registration_month,

        MAKE as vehicle_make,
        MODEL as vehicle_model,
        VEHICLE_TYPE as vehicle_type,
        VEHICLE_USAGE as vehicle_usage,

        date_from_parts(
            try_to_number(FIRST_NZ_REGISTRATION_YEAR),
            try_to_number(FIRST_NZ_REGISTRATION_MONTH),
            1
        ) as first_registration_month_date

    from source_data

)

select *
from renamed_and_casted