{{ config(
    materialized='incremental',
    unique_key='product_id'
) }}

SELECT
    product_id,
    product_name,
    category,
    supplier,
    cost,
    selling_price,
    active_flag,
    updated_at

FROM {{ source('raw', 'products') }}
WHERE product_id IS NOT NULL

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY product_id
    ORDER BY updated_at DESC
) = 1

{% if is_incremental() %}
AND updated_at >= (SELECT DATEADD(day, -3, MAX(updated_at)) FROM {{ this }})
{% endif %}