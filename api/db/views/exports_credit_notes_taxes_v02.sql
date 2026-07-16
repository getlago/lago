SELECT
    cnt.organization_id,
    cnt.id AS lago_id,
    cnt.tax_id AS lago_tax_id,
    cnt.credit_note_id AS lago_credit_note_id,
    cnt.tax_name,
    cnt.tax_code,
    cnt.tax_rate,
    cnt.tax_description,
    cnt.base_amount_cents,
    cnt.amount_cents,
    cnt.amount_currency,
    cnt.created_at,
    cnt.updated_at
FROM credit_notes_taxes AS cnt;
