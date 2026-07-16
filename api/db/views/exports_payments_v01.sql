SELECT
    p.organization_id,
    p.id AS lago_id,
    p.amount_cents,
    p.amount_currency,
    p.payable_payment_status::text AS payment_status,
    p.payment_type::text AS payment_type,
    p.reference,
    p.provider_payment_id AS external_payment_id,
    p.created_at::timestamptz AS created_at,
    p.updated_at::timestamptz AS updated_at,
    CASE
        WHEN p.payable_type = 'Invoice' THEN
            to_json(ARRAY[p.payable_id])
        WHEN p.payable_type = 'PaymentRequest' THEN
            to_json(ARRAY(
                SELECT ai.invoice_id
                FROM invoices_payment_requests ai
                WHERE ai.payment_request_id = p.payable_id
                ORDER BY ai.created_at
            ))
        ELSE
            to_json(ARRAY[]::uuid[])
    END AS invoice_ids
FROM payments AS p;
