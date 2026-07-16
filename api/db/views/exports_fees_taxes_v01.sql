SELECT
    f.organization_id,
    ft.id AS lago_id,
    ft.fee_id AS lago_fee_id,
    ft.tax_id AS lago_tax_id,
    ft.tax_name,
    ft.tax_code,
    ft.tax_rate,
    ft.tax_description,
    ft.amount_cents,
    ft.amount_currency,
    ft.created_at,
    ft.updated_at
FROM fees_taxes AS ft
LEFT JOIN fees AS f ON f.id = ft.fee_id;
