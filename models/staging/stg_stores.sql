{{ config(
    materialized='incremental',
    unique_key='store_id'
) }}

SELECT
    store_id,
    store_name,
    city,
    region,
    manager,
    opened_date,
    updated_at

FROM {{ source('raw', 'stores') }}
WHERE store_id IS NOT NULL

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY store_id
    ORDER BY updated_at DESC
) = 1

{% if is_incremental() %}
AND updated_at >= (SELECT DATEADD(day, -3, MAX(updated_at)) FROM {{ this }})
{% endif %}