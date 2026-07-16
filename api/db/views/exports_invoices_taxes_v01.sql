SELECT
    t.organization_id,
    it.id AS lago_id,
    it.invoice_id AS lago_invoice_id,
    it.tax_id AS lago_tax_id,
    it.tax_name,
    it.tax_code,
    it.tax_rate,
    it.tax_description,
    it.amount_cents,
    it.amount_currency,
    it.fees_amount_cents,
    it.created_at,
    it.updated_at
FROM invoices_taxes AS it
LEFT JOIN taxes AS t ON it.tax_id = t.id;
