{{ config(materialized='incremental', unique_key='quality_issue_id') }}

WITH all_customers AS (
    -- full visibility always — required for duplicate checks
    SELECT customer_id, first_name, last_name, email, phone, region, status, signup_date, updated_at
    FROM {{ source('raw','customers') }}
    WHERE customer_id IS NOT NULL
),

customers_incremental AS (
    -- scoped subset for non-duplicate checks, respects incremental filter
    SELECT * FROM all_customers
    {% if is_incremental() %}
    WHERE updated_at >= (SELECT DATEADD(day, -3, MAX(updated_at)) FROM {{ this }})
    {% endif %}
),

issues AS (
    SELECT customer_id, 'MISSING_PHONE' AS issue_type, 'Phone number is missing' AS issue_description, NULL AS issue_value, updated_at
    FROM customers_incremental WHERE phone IS NULL

    UNION ALL
    SELECT customer_id, 'MISSING_REGION', 'Region is missing', NULL, updated_at
    FROM customers_incremental WHERE region IS NULL

    UNION ALL
    SELECT customer_id, 'INVALID_EMAIL', 'Email format is invalid', email, updated_at
    FROM customers_incremental WHERE email IS NULL OR email NOT LIKE '%@%'

    UNION ALL
    SELECT customer_id, 'INVALID_STATUS', 'Customer status is invalid', status, updated_at
    FROM customers_incremental WHERE status IS NULL OR status NOT IN ('Active','Inactive')

    UNION ALL
    SELECT customer_id, 'FUTURE_SIGNUP_DATE', 'Signup date is in the future', signup_date::STRING, updated_at
    FROM customers_incremental WHERE signup_date > CURRENT_DATE()

    UNION ALL
    -- duplicate checks against FULL table, not the incremental subset
    SELECT customer_id, 'DUPLICATE_EMAIL', 'Customer has duplicate email address', email, updated_at
    FROM all_customers
    WHERE email IS NOT NULL
    QUALIFY COUNT(*) OVER (PARTITION BY email) > 1

    UNION ALL
    SELECT customer_id, 'DUPLICATE_PHONE', 'Customer has duplicate phone number', phone, updated_at
    FROM all_customers
    WHERE phone IS NOT NULL
    QUALIFY COUNT(*) OVER (PARTITION BY phone) > 1
)

SELECT
    MD5(CONCAT(
        COALESCE(i.customer_id,'UNKNOWN'),
        i.issue_type,
        COALESCE(i.issue_value,'UNKNOWN'),
        i.updated_at::STRING
    )) AS quality_issue_id,
    i.customer_id AS entity_id,
    'CUSTOMER' AS entity_type,
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