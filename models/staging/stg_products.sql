{{ config(materialized='incremental',unique_key='product_id') }}

SELECT
    product_id,
    product_name,
    category,
    supplier,
    cost,
    selling_price,
    active_flag,
    updated_at

FROM {{ source("raw", "products") }}

{% if is_incremental() %}

where updated_at >= (SELECT DATEADD(day, -3, MAX(updated_at)) FROM {{ this }})

{% endif %}