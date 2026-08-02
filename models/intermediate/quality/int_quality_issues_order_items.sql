{{ config(materialized='incremental', unique_key='quality_issue_id') }}

WITH all_order_items AS (
    -- full visibility always — required for duplicate checks
    SELECT order_item_id, order_id, product_id, quantity, unit_price, discount, updated_at
    FROM {{ source('raw', 'order_items') }}
    WHERE order_item_id IS NOT NULL
),

order_items_incremental AS (
    -- scoped subset for non-duplicate checks, respects incremental filter
    SELECT * FROM all_order_items
    {% if is_incremental() %}
    WHERE updated_at >= (SELECT DATEADD(day, -3, MAX(updated_at)) FROM {{ this }})
    {% endif %}
),

valid_orders AS (
    SELECT order_id FROM {{ ref('stg_orders') }}
),

issues AS (

    -- Missing order reference
    SELECT order_item_id, 'MISSING_ORDER' AS issue_type, 'Order ID is missing' AS issue_description, NULL AS issue_value, updated_at
    FROM order_items_incremental
    WHERE order_id IS NULL

    UNION ALL

    -- Invalid order reference (order_id doesn't exist in orders)
    SELECT oi.order_item_id, 'INVALID_ORDER', 'Order ID does not exist', oi.order_id::STRING, oi.updated_at
    FROM order_items_incremental oi
    LEFT JOIN valid_orders o ON oi.order_id = o.order_id
    WHERE oi.order_id IS NOT NULL
      AND o.order_id IS NULL

    UNION ALL

    -- Missing product reference
    SELECT order_item_id, 'MISSING_PRODUCT', 'Product ID is missing', NULL, updated_at
    FROM order_items_incremental
    WHERE product_id IS NULL

    UNION ALL

    -- Invalid quantity
    SELECT order_item_id, 'INVALID_QUANTITY', 'Quantity is zero or negative', quantity::STRING, updated_at
    FROM order_items_incremental
    WHERE quantity IS NULL OR quantity <= 0

    UNION ALL

    -- Invalid unit price
    SELECT order_item_id, 'INVALID_UNIT_PRICE', 'Unit price is negative or missing', unit_price::STRING, updated_at
    FROM order_items_incremental
    WHERE unit_price IS NULL OR unit_price < 0

    UNION ALL

    -- Invalid discount (assuming discount is a fraction, 0–1)
    SELECT order_item_id, 'INVALID_DISCOUNT', 'Discount is out of expected range', discount::STRING, updated_at
    FROM order_items_incremental
    WHERE discount IS NOT NULL AND (discount < 0 OR discount > 1)

    UNION ALL

    -- Duplicate order_item_id — full table, not incremental subset
    SELECT order_item_id, 'DUPLICATE_ORDER_ITEM', 'Duplicate order item record', order_item_id::STRING, updated_at
    FROM all_order_items
    QUALIFY COUNT(*) OVER (PARTITION BY order_item_id) > 1

)

SELECT
    MD5(CONCAT(
        COALESCE(i.order_item_id,'UNKNOWN'),
        i.issue_type,
        COALESCE(i.issue_value,'UNKNOWN'),
        i.updated_at::STRING
    )) AS quality_issue_id,
    i.order_item_id AS entity_id,
    'ORDER_ITEM' AS entity_type,
    i.issue_type,
    i.issue_description,
    i.issue_value,
    r.severity,
    r.is_blocking,
    i.updated_at,
    CURRENT_TIMESTAMP() AS detected_at

FROM issues i
LEFT JOIN {{ ref('quality_rules') }} r
    ON i.issue_type = r.issue_type