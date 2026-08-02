{{ config(materialized='table') }}

SELECT
    HASH(store_id) AS store_key,
    store_id,
    store_name,
    city,
    region,
    manager,
    opened_date,
    CURRENT_TIMESTAMP() AS created_at

FROM {{ ref('stg_stores') }}