-- models/monitoring/quality_issues.sql

{{ config(materialized='view') }}

SELECT
    quality_issue_id,
    entity_id,
    entity_type,
    issue_type,
    issue_description,
    issue_value,
    severity,
    is_blocking,
    updated_at,
    detected_at
FROM {{ ref('int_quality_issues_customers') }}

UNION ALL

SELECT
    quality_issue_id,
    entity_id,
    entity_type,
    issue_type,
    issue_description,
    issue_value,
    severity,
    is_blocking,
    updated_at,
    detected_at
FROM {{ ref('int_quality_issues_orders') }}

UNION ALL

SELECT
    quality_issue_id,
    entity_id,
    entity_type,
    issue_type,
    issue_description,
    issue_value,
    severity,
    is_blocking,
    updated_at,
    detected_at
FROM {{ ref('int_quality_issues_order_items') }}