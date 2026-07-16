SELECT
    i.organization_id,
    i.id AS lago_id,
    i.sequential_id,
    i.customer_id,
    i.number,
    i.issuing_date::timestamptz AS issuing_date,
    i.payment_due_date::timestamptz AS payment_due_date,
    i.net_payment_term,
    CASE i.invoice_type
        WHEN 0 THEN 'subscription'
        WHEN 1 THEN 'add_on'
        WHEN 2 THEN 'credit'
        WHEN 3 THEN 'one_off'
        WHEN 4 THEN 'advance_charges'
        WHEN 5 THEN 'progressive_billing'
    END AS invoice_type,
    CASE i.status
        WHEN 0 THEN 'draft'
        WHEN 1 THEN 'finalized'
        WHEN 2 THEN 'voided'
        WHEN 3 THEN 'generating'
        WHEN 4 THEN 'failed'
        WHEN 5 THEN 'open'
        WHEN 6 THEN 'close'
        WHEN 7 THEN 'pending'
    END AS status,
    CASE i.payment_status
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'succeeded'
        WHEN 2 THEN 'failed'
    END AS payment_status,
    i.payment_dispute_lost_at::timestamptz AS payment_dispute_lost_at,
    i.payment_overdue,
    i.currency,
    i.fees_amount_cents,
    i.taxes_amount_cents,
    i.progressive_billing_credit_amount_cents,
    i.coupons_amount_cents,
    i.credit_notes_amount_cents,
    i.sub_total_excluding_taxes_amount_cents,
    i.sub_total_including_taxes_amount_cents,
    i.total_amount_cents,
    i.total_amount_cents - i.total_paid_amount_cents AS total_due_amount_cents,
    i.prepaid_credit_amount_cents,
    i.version_number,
    i.created_at,
    i.updated_at,
    i.voided_at,
    (
        SELECT json_agg(
            json_build_object(
                'lago_id', m.id,
                'key', m.key,
                'value', m.value,
                'created_at', m.created_at
            )
        )
        FROM invoice_metadata AS m
        WHERE m.invoice_id = i.id
    ) AS metadata,
    (
        SELECT json_agg(
            json_build_object(
                'lago_id', ed.id,
                'error_code', ed.error_code,
                'details', ed.details
            )
        )
        FROM error_details AS ed
        WHERE ed.owner_id = i.id
    ) AS error_details
FROM invoices AS i
LEFT JOIN invoice_metadata AS m ON i.id = m.invoice_id
WHERE i.status IN (0, 1, 2, 4, 7);
