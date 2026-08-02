{{ config(materialized='incremental', unique_key=['order_id','order_item_id']) }}

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount,
    updated_at,
    HASH(
        order_item_id, order_id, product_id, quantity, unit_price, discount
    ) AS row_hash

{% if is_incremental() %}
FROM {{ source('raw', 'order_items_stream') }}
{% else %}
FROM {{ source('raw', 'order_items') }}
{% endif %}

WHERE order_item_id IS NOT NULL AND order_id IS NOT NULL

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_id, order_item_id
    ORDER BY updated_at DESC
) = 1