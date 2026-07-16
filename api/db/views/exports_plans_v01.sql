SELECT
  p.organization_id,
  p.id AS lago_id,
  p.name,
  p.invoice_display_name,
  p.created_at,
  p.updated_at,
  p.code,
  CASE p.interval
    WHEN 0 then 'weekly'
    WHEN 1 then 'monthly'
    WHEN 2 then 'yearly'
    WHEN 3 then 'quarterly'
  END AS plan_interval,
  p.description,
  p.amount_cents,
  p.amount_currency,
  p.trial_period,
  p.pay_in_advance,
  p.bill_charges_monthly,
  p.parent_id,
  to_json (
    ARRAY(
      SELECT
        pt.tax_id AS lago_tax_id
      FROM
        plans_taxes AS pt
      WHERE
        pt.plan_id = p.id
    )
  ) AS lago_taxes_ids
FROM
  plans AS p
WHERE
  p.deleted_at IS NULL;
