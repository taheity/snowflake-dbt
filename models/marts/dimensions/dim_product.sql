{{ config(materialized='table') }}

SELECT
    HASH(product_id) AS product_key,
    product_id,
    product_name,
    category,
    supplier,
    cost,
    selling_price,
    active_flag,
    CURRENT_TIMESTAMP() AS created_at

FROM {{ ref('stg_products') }}