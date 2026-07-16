SELECT
  cp.organization_id,
  cp.id AS lago_id,
  cp.name,
  cp.code,
  cp.description,
  CASE cp.coupon_type
    WHEN 0 THEN 'fixed_amount'
    WHEN 1 THEN 'percentage'
  END AS coupon_type,
  cp.amount_cents,
  cp.amount_currency,
  cp.percentage_rate,
  CASE cp.frequency
    WHEN 0 THEN 'once'
    WHEN 1 THEN 'recurring'
    WHEN 2 THEN 'forever'
  END as frequency,
  cp.frequency_duration,
  cp.reusable,
  cp.limited_plans,
  cp.limited_billable_metrics,
  to_json (
    ARRAY(
      SELECT
        cpt.plan_id
      FROM
        coupon_targets AS cpt
      WHERE
        cpt.coupon_id = cp.id
        AND cpt.plan_id IS NOT NULL
    )
  ) AS lago_plan_ids,
  to_json (
    ARRAY(
      SELECT
        cpt.billable_metric_id
      FROM
        coupon_targets AS cpt
      WHERE
        cpt.coupon_id = cp.id
        AND cpt.billable_metric_id IS NOT NULL
    )
  ) AS lago_billable_metrics_ids,
  cp.created_at,
  CASE cp.expiration
    WHEN 0 then 'no_expiration'
    WHEN 1 then 'time_limit'
  END AS expiration,
  cp.expiration_at,
  cp.terminated_at,
  cp.updated_at
FROM
  coupons AS cp;
