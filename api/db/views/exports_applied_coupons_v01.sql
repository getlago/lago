SELECT
    cp.organization_id,
    ac.id AS lago_id,
    ac.coupon_id AS lago_coupon_id,
    ac.customer_id AS lago_customer_id,
    CASE ac.status
        WHEN 0 THEN 'active'
        WHEN 1 THEN 'terminated'
    END AS status,
    ac.amount_cents,
    CASE ac.frequency
        WHEN 0 THEN null
        WHEN 1 THEN null
        ELSE
            CASE
                WHEN cp.coupon_type = 1 THEN NULL -- coupon is percentage
                ELSE
                    ac.amount_cents - (
                        SELECT SUM(cr.amount_cents)::bigint
                        FROM credits AS cr
                        WHERE cr.applied_coupon_id = ac.id
                    )
            END
    END AS amount_cents_remaining,
    ac.amount_currency,
    ac.percentage_rate,
    CASE ac.frequency
        WHEN 0 THEN 'once'
        WHEN 1 THEN 'recurring'
        WHEN 2 THEN 'forever'
    END AS frequency,
    ac.frequency_duration,
    ac.frequency_duration_remaining,
    ac.created_at,
    ac.terminated_at,
    ac.updated_at,
    (
        SELECT json_agg(
            json_build_object(
                'lago_id', cr.id,
                'amount_cents', cr.amount_cents,
                'amount_currency', cr.amount_currency,
                'before_taxes', cr.before_taxes
            )
        )
        FROM credits AS cr
        WHERE cr.applied_coupon_id = ac.id
    ) AS credits
FROM applied_coupons AS ac
LEFT JOIN coupons AS cp ON cp.id = ac.coupon_id;
