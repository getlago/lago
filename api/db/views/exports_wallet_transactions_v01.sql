SELECT
    c.organization_id,
    wt.id AS lago_id,
    wt.wallet_id AS lago_wallet_id,
    CASE wt.status
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'settled'
        WHEN 2 THEN 'failed'
    END AS status,
    CASE wt.source
        WHEN 0 THEN 'manual'
        WHEN 1 THEN 'interval'
        WHEN 2 THEN 'threshold'
    END AS source,
    CASE wt.transaction_status
        WHEN 0 THEN 'purchased'
        WHEN 1 THEN 'granted'
        WHEN 2 THEN 'voided'
        WHEN 3 THEN 'invoiced'
    END AS  transaction_status,
    CASE wt.transaction_type
        WHEN 0 THEN 'inbound'
        WHEN 1 THEN 'outbound'
    END AS transaction_type,
    wt.amount,
    wt.credit_amount,
    wt.settled_at,
    wt.failed_at,
    wt.created_at,
    wt.updated_at,
    wt.invoice_requires_successful_payment,
    wt.metadata
FROM wallet_transactions AS wt
LEFT JOIN wallets AS w ON wt.wallet_id = w.id
LEFT JOIN customers AS c ON c.id = w.customer_id;
