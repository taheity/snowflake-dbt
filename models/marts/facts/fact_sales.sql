{{ config(
    materialized='incremental',
    unique_key='order_item_id'
) }}

SELECT

    HASH(oi.order_item_id) AS sales_key,

    -- Degenerate dimensions
    o.order_id,
    oi.order_item_id,
    o.order_date,

    -- Dimension keys
    c.customer_key,
    p.product_key,
    s.store_key,

    -- Measures
    oi.quantity,
    oi.unit_price,
    oi.discount,

    -- Revenue calculations
    oi.quantity * oi.unit_price AS gross_sales_amount,

    (oi.quantity * oi.unit_price) * COALESCE(oi.discount, 0) AS discount_amount,

    (oi.quantity * oi.unit_price)
        - ((oi.quantity * oi.unit_price) * COALESCE(oi.discount, 0))
        AS net_sales_amount,

    -- Cost
    oi.quantity * p.cost AS cost_amount,

    -- Profit
    (
        (oi.quantity * oi.unit_price)
        - ((oi.quantity * oi.unit_price) * COALESCE(oi.discount, 0))
    )
    - (oi.quantity * p.cost) AS profit_amount,

    -- Operational attributes
    o.sales_channel,
    o.payment_method,
    o.order_status,

    -- Incremental tracking
    o.updated_at AS order_updated_at,
    oi.updated_at AS order_item_updated_at,

    -- created_at only set on first insert, preserved on merge
    {% if is_incremental() %}
        COALESCE(existing.created_at, CURRENT_TIMESTAMP()) AS created_at
    {% else %}
        CURRENT_TIMESTAMP() AS created_at
    {% endif %}
FROM {{ ref('int_orders_quality_status') }} o

INNER JOIN {{ ref('int_order_items_quality_status') }} oi
    ON o.order_id = oi.order_id

LEFT JOIN {{ ref('dim_customer') }} c
    ON o.customer_id = c.customer_id 

LEFT JOIN {{ ref('dim_product') }} p
    ON oi.product_id = p.product_id

LEFT JOIN {{ ref('dim_store') }} s
    ON o.store_id = s.store_id

{% if is_incremental() %}
LEFT JOIN {{ this }} existing
    ON oi.order_item_id = existing.order_item_id
{% endif %}

WHERE NOT o.is_quarantined
  AND NOT oi.is_quarantined
  and not c.IS_QUARANTINED

{% if is_incremental() %}
AND (
    o.updated_at >= (SELECT DATEADD(day, -3, MAX(order_updated_at)) FROM {{ this }})
    OR
    oi.updated_at >= (SELECT DATEADD(day, -3, MAX(order_item_updated_at)) FROM {{ this }})
)
{% endif %}