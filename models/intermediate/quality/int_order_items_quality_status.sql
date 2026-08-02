{{ config(materialized='view') }}

SELECT
    oi.*,
    CASE WHEN q.entity_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_quarantined

FROM {{ ref('stg_order_items') }} oi

LEFT JOIN {{ ref('int_quality_issues_order_items') }} q
    ON oi.order_item_id = q.entity_id
    AND q.entity_type = 'ORDER_ITEM'
    AND q.is_blocking = TRUE