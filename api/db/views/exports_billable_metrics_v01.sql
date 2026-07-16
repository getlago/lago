SELECT
  bm.organization_id,
  bm.id AS lago_id,
  bm.name,
  bm.code,
  bm.description,
  CASE bm.aggregation_type
    WHEN 0 THEN 'count_agg'
    WHEN 1 THEN 'sum_agg'
    WHEN 2 THEN 'max_agg'
    WHEN 3 THEN 'unique_count_agg'
    WHEN 5 THEN 'weighted_sum_agg'
    WHEN 6 THEN 'latest_agg'
    WHEN 7 THEN 'custom_agg'
    ELSE 'unknown'
  END AS aggregation_type,
  bm.weighted_interval::text,
  bm.recurring,
  bm.rounding_function::text,
  bm.rounding_precision,
  bm.created_at,
  bm.updated_at,
  bm.field_name,
  bm.expression,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'key', bmf.key,
          'values', bmf.values
        )
      )
      FROM billable_metric_filters AS bmf
      WHERE bmf.billable_metric_id = bm.id
        AND bmf.deleted_at IS NULL
    ),
    '[]'::json
  ) AS filters
FROM billable_metrics AS bm
WHERE bm.deleted_at IS NULL;
