SELECT
  c.organization_id,
  c.id AS lago_id,
  c.billing_entity_id,
  c.external_id,
  c.account_type::text,
  c.name,
  c.firstname,
  c.lastname,
  c.customer_type::text,
  c.sequential_id,
  c.slug,
  c.created_at,
  c.updated_at,
  c.country,
  c.address_line1,
  c.address_line2,
  c.state,
  c.zipcode,
  c.email,
  c.city,
  c.url,
  c.phone,
  c.legal_name,
  c.legal_number,
  c.currency,
  c.tax_identification_number,
  c.timezone,
  COALESCE(c.timezone, o.timezone, 'UTC') AS applicable_timezone,
  c.net_payment_term,
  c.external_salesforce_id,
  CASE c.finalize_zero_amount_invoice
    WHEN 0 THEN 'inherit'
    WHEN 1 THEN 'skip'
    WHEN 2 THEN 'finalize'
  END AS finalize_zero_amount_invoice,
  c.skip_invoice_custom_sections,
  c.payment_provider,
  c.payment_provider_code,
  c.invoice_grace_period,
  c.vat_rate,
  COALESCE(c.invoice_grace_period, o.invoice_grace_period) AS applicable_invoice_grace_period,
  c.document_locale,
  ppc.provider_customer_id,
  ppc.settings AS provider_settings,
  to_json(
    ARRAY(
      SELECT ct.tax_id AS lago_tax_id
      FROM customers_taxes AS ct
      WHERE ct.customer_id = c.id
    )
  ) AS lago_taxes_ids
FROM customers c
LEFT JOIN organizations o ON o.id = c.organization_id
LEFT JOIN payment_provider_customers ppc ON ppc.customer_id = c.id
  AND ppc.deleted_at IS NULL;