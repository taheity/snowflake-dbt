{{ config(materialized='incremental',unique_key=['order_id','order_item_id']) }}
SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount,
    updated_at,
    HASH(
        order_item_id,order_id, product_id, quantity, unit_price,
        discount
    ) AS row_hash

FROM {{ source('raw', 'order_items_stream') }}   -- the Stream, not the base table
WHERE order_item_id IS NOT NULL and order_id is not null

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_id,order_item_id
    ORDER BY updated_at DESC
) = 1