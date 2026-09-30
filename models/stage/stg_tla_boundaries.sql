with source_data as (

    select *
    from {{ source('nz_public_data', 'tla_boundaries_raw') }}

),

rename_and_casted as (

    select 
        nullif(trim(tla_code::varchar), '') as tla_code,
        nullif(trim(tla_name::varchar), '') as tla_name,
        nullif(trim(tla_name_ascii::varchar), '') as tla_name_ascii,
        try_to_number(boundary_year)::integer as boundary_year,
        nullif(trim(boundary_wkt::varchar), '') as boundary_wkt
    
    from source_data

),

with_geography as (

    select
        tla_code,
        tla_name,
        tla_name_ascii,

        -- Used to match the uppercase TLA name in the vehicle table.
        upper(tla_name_ascii) as tla_name_key,

        boundary_year,
        boundary_wkt,

        -- Used to transfer WKT into snowflake GEOGRAPHY
        try_to_geography(boundary_wkt) as tla_geography

    from rename_and_casted
)

select
    tla_code,
    tla_name,
    tla_name_ascii,
    tla_name_key,
    boundary_year,
    boundary_wkt,
    tla_geography,

    --Check the boundary be transformed success or not
    case 
        when tla_geography is not null then true 
        else false
    end as is_valid_tla_geography

from with_geography