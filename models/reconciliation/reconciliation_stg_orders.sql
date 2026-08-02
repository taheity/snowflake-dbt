-- reconciliation_stg_orders.sql
{{ config(materialized='table') }}

SELECT
    'ORDER' AS entity_type,
    r.order_id AS entity_id,
    NULL AS related_entity_id,
    'HASH_MISMATCH' AS issue_type,
    FALSE AS is_blocking,
    CURRENT_TIMESTAMP() AS detected_at
FROM {{ source('raw', 'orders') }} r
INNER JOIN {{ ref('stg_orders') }} s
    ON r.order_id = s.order_id
WHERE r.order_id IS NOT NULL
  AND HASH(
        r.order_id, r.customer_id, r.order_date, r.store_id,
        r.sales_channel, r.payment_method, r.order_status
      ) != s.row_hash

UNION ALL

SELECT
    'ORDER',
    r.order_id,
    NULL,
    'MISSING_IN_STAGING',
    FALSE,
    CURRENT_TIMESTAMP()
FROM {{ source('raw', 'orders') }} r
LEFT JOIN {{ ref('stg_orders') }} s
    ON r.order_id = s.order_id
WHERE r.order_id IS NOT NULL
  AND s.order_id IS NULL