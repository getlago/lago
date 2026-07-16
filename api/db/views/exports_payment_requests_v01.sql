SELECT
    pr.organization_id,
    pr.id AS lago_id,
    pr.customer_id AS lago_customer_id,
    pr.payment_attempts,
    pr.amount_cents,
    pr.amount_currency,
    pr.email,
    pr.ready_for_payment_processing,
    CASE pr.payment_status
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'succeeded'
        WHEN 2 THEN 'failed'
    END AS payment_status,
    to_json(
        ARRAY(
            SELECT p.id
            FROM payments AS p
            WHERE p.payable_id = pr.id AND p.payable_type = 'PaymentRequest'
            ORDER BY p.created_at
        )
    ) AS payment_ids,
    to_json(
        ARRAY(
            SELECT apr.invoice_id
            FROM invoices_payment_requests AS apr
            WHERE apr.payment_request_id = pr.id
            ORDER BY apr.created_at
        )
    ) AS invoice_ids,
    pr.created_at,
    pr.updated_at
FROM payment_requests AS pr;