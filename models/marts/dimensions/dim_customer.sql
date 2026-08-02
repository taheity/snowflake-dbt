{{ config(materialized='table') }}

SELECT
    HASH(c.customer_id) AS customer_key,
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.city,
    c.region,
    c.signup_date,
    c.customer_segment,
    c.status,
    COALESCE(cq.is_quarantined, FALSE) AS is_quarantined,
    qi.issue_summary AS data_quality_issue,
    CURRENT_TIMESTAMP() AS created_at

FROM {{ ref('stg_customers') }} c

LEFT JOIN {{ ref('int_customers_quality_status') }} cq
    ON c.customer_id = cq.customer_id

LEFT JOIN (
    SELECT
        entity_id AS customer_id,
        LISTAGG(issue_type, ', ') WITHIN GROUP (ORDER BY issue_type) AS issue_summary
    FROM {{ ref('int_quality_issues_customers') }}
    WHERE entity_type = 'CUSTOMER'
    GROUP BY entity_id
) qi
    ON c.customer_id = qi.customer_id