WITH billable_metric_filters as (
  SELECT
    billable_metrics.organization_id as bm_organization_id,
    billable_metrics.id AS bm_id,
    billable_metrics.code AS bm_code,
    filters.key AS filter_key,
    filters.values AS filter_values
  FROM billable_metrics
    INNER JOIN billable_metric_filters filters
 		  ON filters.billable_metric_id = billable_metrics.id
  WHERE
    billable_metrics.deleted_at IS NULL
    AND filters.deleted_at IS NULL
)


SELECT
  events.organization_id,
  events.transaction_id,
  events.properties,
  billable_metrics.code AS billable_metric_code,
  billable_metrics.aggregation_type != 0 AS field_name_mandatory,
  billable_metrics.aggregation_type IN (1,2,5,6) AS numeric_field_mandatory,
  events.properties ->> billable_metrics.field_name::text AS field_value,
  events.properties ->> billable_metrics.field_name::text ~ '^-?\d+(\.\d+)?$' AS is_numeric_field_value,
  events.properties ? billable_metric_filters.filter_key as has_filter_keys,
  (events.properties ->> billable_metric_filters.filter_key) = ANY (billable_metric_filters.filter_values) as has_valid_filter_values
FROM
  events
    LEFT JOIN billable_metrics ON billable_metrics.code = events.code
      AND events.organization_id = billable_metrics.organization_id
    LEFT JOIN billable_metric_filters ON billable_metrics.id = billable_metric_filters.bm_id
WHERE
  events.deleted_at IS NULL
  AND events.created_at >= date_trunc('hour', NOW()) - INTERVAL '1 hour'
  AND events.created_at < date_trunc('hour', NOW())
  AND billable_metrics.deleted_at IS NULL
