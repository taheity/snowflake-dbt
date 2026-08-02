-- reconciliation_stg_order_items.sql
{{ config(materialized='table') }}

SELECT
    'ORDER_ITEM' AS entity_type,
    r.order_item_id AS entity_id,
    r.order_id AS related_entity_id,
    'HASH_MISMATCH' AS issue_type,
    FALSE AS is_blocking,
    CURRENT_TIMESTAMP() AS detected_at
FROM {{ source('raw', 'order_items') }} r
INNER JOIN {{ ref('stg_order_items') }} s
    ON r.order_item_id = s.order_item_id
    AND r.order_id = s.order_id
WHERE r.order_item_id IS NOT NULL
  AND r.order_id IS NOT NULL
  AND HASH(
        r.order_item_id, r.order_id, r.product_id,
        r.quantity, r.unit_price, r.discount
      ) != s.row_hash

UNION ALL

SELECT
    'ORDER_ITEM',
    r.order_item_id,
    r.order_id AS related_entity_id,
    'MISSING_IN_STAGING',
    FALSE,
    CURRENT_TIMESTAMP()
FROM {{ source('raw', 'order_items') }} r
LEFT JOIN {{ ref('stg_order_items') }} s
    ON r.order_item_id = s.order_item_id
    AND r.order_id = s.order_id
WHERE r.order_item_id IS NOT NULL
  AND r.order_id IS NOT NULL
  AND s.order_item_id IS NULL