{{ config(materialized='incremental', unique_key='order_id') }}

SELECT
    order_id,
    customer_id,
    order_date,
    store_id,
    sales_channel,
    payment_method,
    order_status,
    updated_at,
    HASH(
        order_id, customer_id, order_date, store_id,
        sales_channel, payment_method, order_status
    ) AS row_hash

{% if is_incremental() %}
FROM {{ source('raw', 'orders_stream') }}
{% else %}
FROM {{ source('raw', 'orders') }}
{% endif %}

WHERE order_id IS NOT NULL

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_id
    ORDER BY updated_at DESC
) = 1