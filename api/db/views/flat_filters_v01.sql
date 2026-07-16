-- This view is used on events_processor side to check filters matching on events received for organization using the Clickhouse store
-- It then allows us to expire the usage chage directly within the events events_processor service
SELECT
  billable_metrics.organization_id AS organization_id,
  billable_metrics.code AS billable_metric_code,
  charges.plan_id AS plan_id,
  charges.id AS charge_id,
  charges.updated_at AS charge_updated_at,
  charge_filters.id AS charge_filter_id,
  charge_filters.updated_at AS charge_filter_updated_at,
  CASE WHEN charge_filters.id IS NOT NULL
  THEN
	  jsonb_object_agg(
	    COALESCE(billable_metric_filters.key, ''),
	    CASE
	      WHEN charge_filter_values.values::text[] && ARRAY['__ALL_FILTER_VALUES__']
	      THEN billable_metric_filters.values
	      ELSE charge_filter_values.values
	    end
	  )
	  ELSE NULL
  END AS filters
FROM billable_metrics
  INNER JOIN charges ON charges.billable_metric_id = billable_metrics.id
  LEFT JOIN charge_filters ON charge_filters.charge_id = charges.id
  LEFT JOIN charge_filter_values ON charge_filter_values.charge_filter_id = charge_filters.id
  LEFT JOIN billable_metric_filters ON billable_metric_filters.id = charge_filter_values.billable_metric_filter_id
WHERE
  billable_metrics.deleted_at IS NULL
  AND charges.deleted_at IS NULL
  AND charge_filters.deleted_at IS NULL
  AND charge_filter_values.deleted_at IS NULL
  AND billable_metric_filters.deleted_at IS NULL
GROUP BY
  billable_metrics.organization_id,
  billable_metrics.code,
  charges.plan_id,
  charges.id,
  charges.updated_at,
  charge_filters.id,
  charge_filters.updated_at
