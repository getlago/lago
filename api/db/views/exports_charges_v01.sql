SELECT
  p.organization_id,
  c.id AS lago_id,
  c.billable_metric_id AS lago_billable_metric_id,
  c.invoice_display_name,
  c.created_at,
  c.updated_at,
  CASE c.charge_model
    WHEN 0 THEN 'standard'
    WHEN 1 THEN 'graduated'
    WHEN 2 THEN 'package'
    WHEN 3 THEN 'percentage'
    WHEN 4 THEN 'volume'
    WHEN 5 THEN 'graduated_percentage'
    WHEN 6 THEN 'custom'
    WHEN 7 THEN 'dynamic'
  END AS charge_model,
  c.invoiceable,
  CASE c.regroup_paid_fees
    WHEN 0 THEN 'invoice'
  END AS regroup_paid_fees,
  c.pay_in_advance,
  c.prorated,
  c.min_amount_cents,
  c.properties,
  (
    SELECT
      json_agg (
        json_build_object (
          'invoice_display_name',
          cf.invoice_display_name,
          'properties',
          cf.properties,
          'values',
          (
            SELECT
              json_agg (
                json_build_object (cfcv.billable_metric_filter_id, cfcv.values)
              )
            FROM
              charge_filter_values AS cfcv
            WHERE
              cfcv.charge_filter_id = cf.id
          )
        )
      )
    FROM
      charge_filters AS cf
    WHERE
      cf.charge_id = c.id
  ) AS charge_filters
FROM
  charges AS c
  LEFT JOIN plans AS p ON p.id = c.plan_id;
