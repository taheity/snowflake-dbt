{{ config(materialized='view') }}

SELECT
    o.*,
    CASE WHEN q.entity_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_quarantined

FROM {{ ref('stg_orders') }} o

LEFT JOIN {{ ref('int_quality_issues_orders') }} q
    ON o.order_id = q.entity_id
    AND q.entity_type = 'ORDER'
    AND q.is_blocking = TRUE