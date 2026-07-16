SELECT
    f.organization_id,
    f.id AS lago_id,
    f.charge_id AS lago_charge_id,
    f.charge_filter_id AS lago_charge_filter_id,
    f.invoice_id AS lago_invoice_id,
    f.subscription_id AS lago_subscription_id,
    c.id AS lago_customer_id,
    json_build_object(    
        'type', CASE f.fee_type
            WHEN 0 THEN 'charge'       -- Assuming 0 maps to :charge
            WHEN 1 THEN 'add_on'       -- Assuming 1 maps to :add_on
            WHEN 2 THEN 'subscription' -- Assuming 2 maps to :subscription
            WHEN 3 THEN 'credit'       -- Assuming 3 maps to :credit
            WHEN 4 THEN 'commitment'   -- Assuming 4 maps to :commitment
            ELSE 'unknown'
        END,
        'code', CASE f.fee_type
            WHEN 0 THEN bm.code -- 0 is charge
            WHEN 1 THEN ao.code -- 1 is add_on
            WHEN 3 THEN 'credit' -- 3 is credit
            ELSE p.code -- everything else is subscription
        END,
        'name', CASE f.fee_type
            WHEN 0 THEN bm.name -- 0 is charge  
            WHEN 1 THEN ao.name -- 1 is add_on
            WHEN 3 THEN 'credit' -- 3 is credit
            ELSE p.name -- everything else is subscription
        END,
        'description', CASE f.fee_type
            WHEN 0 THEN bm.description -- 0 is charge
            WHEN 1 THEN ao.description -- 1 is add_on
            WHEN 3 THEN 'credit' -- 3 is credit
            ELSE p.description -- everything else is subscription
        END,
        'invoice_display_name', COALESCE(
            f.invoice_display_name,
            CASE f.fee_type
                WHEN 0 THEN COALESCE(
                    ch.invoice_display_name,
                    bm.name
                ) -- 0 is charge
                WHEN 1 THEN COALESCE(ao.invoice_display_name, ao.name) -- 1 is add_on
                WHEN 3 THEN 'credit' -- 3 is credit
                ELSE p.invoice_display_name -- everything else is subscription
            END
        ),
        'filters', (
            SELECT json_agg(
                json_build_object(
                    'id', cf.id,
                    'charge_id', cf.charge_id,
                    'properties', cf.properties,
                    'invoice_display_name', cf.invoice_display_name
                )
            )
            FROM charge_filters AS cf
            WHERE cf.charge_id = f.charge_id
        ),
        'lago_item_id', CASE f.fee_type
            WHEN 0 THEN bm.id -- 0 is charge
            WHEN 1 THEN ao.id -- 1 is add_on
            WHEN 3 THEN invoiceable_id -- 3 is credit
            ELSE f.subscription_id -- everything else is subscription
        END,
        'item_type', CASE f.fee_type
            WHEN 0 THEN 'billable_metric' -- 0 is charge
            WHEN 1 THEN 'add_on' -- 1 is add_on
            WHEN 3 THEN 'wallet_transaction' -- 3 is credit
            ELSE 'subscription' -- everything else is subscription
        END,
        'grouped_by', f.grouped_by
    ) AS item,
    f.pay_in_advance,
    f.amount_cents,
    ch.invoiceable AS invoiceable,
    f.taxes_amount_cents,
    f.taxes_precise_amount_cents,
    f.taxes_rate,
    f.amount_cents + f.taxes_amount_cents AS total_amount_cents,
    f.amount_currency AS currency,
    f.units,
    f.description,
    f.precise_amount_cents,
    f.precise_unit_amount,
    f.precise_coupons_amount_cents,
    f.precise_amount_cents + f.taxes_precise_amount_cents AS precise_total_amount_cents,
    f.events_count,
    -- payment-status
    CASE f.payment_status
        WHEN 0 THEN 'pending'    -- Assuming 0 maps to :pending
        WHEN 1 THEN 'succeeded'  -- Assuming 1 maps to :succeeded
        WHEN 2 THEN 'failed'     -- Assuming 2 maps to :failed
        WHEN 3 THEN 'refunded'   -- Assuming 3 maps to :refunded
        ELSE 'unknown'
    END AS payment_status,
    f.created_at,
    f.succeeded_at,
    f.failed_at,
    f.refunded_at,
    f.amount_details,
    f.updated_at,
    CASE f.fee_type
        WHEN 0 THEN (f.properties->>'charges_from_datetime')::timestamptz::text
        ELSE (f.properties->>'from_datetime')::timestamptz::text
    END AS from_date,
    CASE f.fee_type
        WHEN 0 THEN (f.properties->>'charges_to_datetime')::timestamptz::text
        ELSE (f.properties->>'to_datetime')::timestamptz::text
    END AS to_date
FROM fees AS f
LEFT JOIN subscriptions AS s ON f.subscription_id = s.id
LEFT JOIN customers AS c ON s.customer_id = c.id
LEFT JOIN charges AS ch ON f.charge_id = ch.id
LEFT JOIN billable_metrics AS bm ON ch.billable_metric_id = bm.id
LEFT JOIN add_ons AS ao ON f.add_on_id = ao.id
LEFT JOIN plans AS p ON s.plan_id = p.id