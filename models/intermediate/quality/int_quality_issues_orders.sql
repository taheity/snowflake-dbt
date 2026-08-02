{{ config(materialized='incremental', unique_key='quality_issue_id') }}

WITH all_orders AS (
    -- full visibility always — required for duplicate checks
    SELECT order_id, customer_id, order_date, store_id, sales_channel, payment_method, order_status, updated_at
    FROM {{ source('raw', 'orders') }}
    WHERE order_id IS NOT NULL
),

orders_incremental AS (
    -- scoped subset for non-duplicate checks, respects incremental filter
    SELECT * FROM all_orders
    {% if is_incremental() %}
    WHERE updated_at >= (SELECT DATEADD(day, -3, MAX(updated_at)) FROM {{ this }})
    {% endif %}
),

customers AS (
    SELECT customer_id FROM {{ ref('stg_customers') }}
),

issues AS (

    -- Missing customer
    SELECT order_id, 'MISSING_CUSTOMER' AS issue_type, 'Customer ID is missing' AS issue_description, NULL AS issue_value, updated_at
    FROM orders_incremental
    WHERE customer_id IS NULL

    UNION ALL

    -- Invalid customer (doesn't exist in customer dimension)
    SELECT o.order_id, 'INVALID_CUSTOMER', 'Customer ID does not exist', o.customer_id::STRING, o.updated_at
    FROM orders_incremental o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.customer_id IS NOT NULL
      AND c.customer_id IS NULL

    UNION ALL

    -- Future order date
    SELECT order_id, 'FUTURE_ORDER_DATE', 'Order date is in the future', order_date::STRING, updated_at
    FROM orders_incremental
    WHERE order_date > CURRENT_DATE()

    UNION ALL

    -- Invalid status
    SELECT order_id, 'INVALID_STATUS', 'Order status is invalid', order_status, updated_at
    FROM orders_incremental
    WHERE order_status IS NULL
       OR order_status NOT IN ('Completed')  -- adjust to your actual valid set

    UNION ALL

    -- Duplicate customer + order_date combination — full table, not incremental subset
    SELECT order_id, 'DUPLICATE_CUSTOMER_DATE', 'Multiple orders share same customer and order date', 
           CONCAT(customer_id, '|', order_date::STRING), updated_at
    FROM all_orders
    WHERE customer_id IS NOT NULL
    QUALIFY COUNT(*) OVER (PARTITION BY customer_id, order_date) > 1

)

SELECT
    MD5(CONCAT(
        COALESCE(i.order_id,'UNKNOWN'),
        i.issue_type,
        COALESCE(i.issue_value,'UNKNOWN'),
        i.updated_at::STRING
    )) AS quality_issue_id,
    i.order_id AS entity_id,
    'ORDER' AS entity_type,
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