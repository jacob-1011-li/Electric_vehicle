select *
from {{ source('nz_public_data', 'motor_vehicle_raw') }}