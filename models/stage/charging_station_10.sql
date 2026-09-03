with stage_10 as (
  select
    station_cols:OBJECTID::int as station_id,
    station_cols:NAME::string as station_name,
    station_cols:ADDRESS::string as station_address,
    station_cols:latitude::double as latitude,
    station_cols:longitude::double as longitude,
    station_cols:OPERATOR::string as operator,
    station_cols:OWNER::string as owner,
    station_cols:carParkCount::int as car_park_count,
    station_cols:connectorsList::string as connectors,
    station_cols:currentType::string as current_type,
    to_date(station_cols:dateFirstOperational::string, 'dd/MM/yyyy') as first_operational_date,
    station_cols:hasCarparkCost::boolean as has_carpark_cost,
    station_cols:hasChargingCost::boolean as has_charging_cost,
    station_cols:hasTouristAttraction::boolean as has_tourist_attraction,
    station_cols:is24Hours::boolean as is_24_hours,
    station_cols:maxTimeLimit::string as max_time_limit,
    station_cols:numberOfConnectors::int as connector_count,
    station_cols:GlobalID::string as global_id
  from 
    {{ source('nz_public_data', 'charging_station') }}
),

flattened_kw as (

  select 

    s.*,

    f.value as raw_connector,

    regexp_substr(f.value, '[0-9]+\\.?[0-9]*\\s*kW') as kw_text,

    try_to_number(regexp_substr(f.value, '[0-9]+\\.?[0-9]*')) as kw_value

  from stage_10 s,

  lateral flatten(

    input => regexp_substr_all(s.connectors, '\\{[^}]*Status: Operative[^}]*\\}')

  ) f

),

aggregated as (
  select 
    station_id,
    station_name,
    station_address,
    latitude,
    longitude,
    operator,
    owner,
    car_park_count,
    connectors,
    current_type,
    first_operational_date,
    has_carpark_cost,
    has_charging_cost,
    has_tourist_attraction,
    is_24_hours,
    max_time_limit,
    connector_count,
    global_id,
    round(avg(kw_value), 1) as avg_kw_for_operative,
    count(*) as operative_connector_count
  from flattened_kw
  group by
    station_id,
    station_name,
    station_address,
    latitude,
    longitude,
    operator,
    owner,
    car_park_count,
    connectors,
    current_type,
    first_operational_date,
    has_carpark_cost,
    has_charging_cost,
    has_tourist_attraction,
    is_24_hours,
    max_time_limit,
    connector_count,
    global_id
)

select * 
from aggregated
