SELECT
  ins.organization_id,
  ins.id AS lago_id,
  ins.invoice_id AS lago_invoice_id,
  ins.regenerated_invoice_id AS lago_regenerated_invoice_id,
  ins.subscription_id AS lago_subscription_id,
  ins.created_at,
  ins.updated_at,
  ins.from_datetime,
  ins.to_datetime,
  ins.charges_from_datetime,
  ins.charges_to_datetime,
  ins.timestamp,
  ins.invoicing_reason::text as invoicing_reason
FROM invoice_subscriptions AS ins;
