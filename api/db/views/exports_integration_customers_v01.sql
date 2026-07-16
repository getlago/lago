SELECT
  ic.id AS lago_id,
  ic.organization_id,
  ic.customer_id as lago_customer_id,
  ic.integration_id AS lago_integration_id,
  ic.external_customer_id,
  ic.type,
  ic.settings,
  ic.created_at,
  ic.updated_at
FROM integration_customers AS ic;
