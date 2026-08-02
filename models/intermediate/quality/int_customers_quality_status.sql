{{ config(materialized='view') }}

SELECT
    c.*,
    CASE WHEN q.entity_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_quarantined

FROM {{ ref('stg_customers') }} c

LEFT JOIN {{ ref('int_quality_issues_customers') }} q
    ON c.customer_id = q.entity_id
    AND q.entity_type = 'CUSTOMER'
    AND q.is_blocking = TRUE