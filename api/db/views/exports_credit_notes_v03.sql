SELECT
  cn.organization_id,
  cn.id AS lago_id,
  cn.sequential_id,
  cn.number,
  cn.invoice_id AS lago_invoice_id,
  cn.issuing_date,
  CASE cn.credit_status
    WHEN 0 THEN 'available'
    WHEN 1 THEN 'consumed'
    WHEN 2 THEN 'voided'
  END AS credit_status,
  CASE cn.refund_status
    WHEN 0 THEN 'pending'
    WHEN 1 THEN 'succeeded'
    WHEN 2 THEN 'failed'
  END AS refund_status,
  CASE cn.reason
    WHEN 0 THEN 'duplicated_charge'
    WHEN 1 THEN 'product_unsatisfactory'
    WHEN 2 THEN 'order_change'
    WHEN 3 THEN 'order_cancellation'
    WHEN 4 THEN 'fraudulent_charge'
    WHEN 5 THEN 'other'
  END as reason,
  cn.description,
  cn.total_amount_currency AS currency,
  cn.total_amount_cents,
  cn.taxes_amount_cents,
  ROUND(
    (
      SELECT
        SUM(ci.precise_amount_cents)::bigint
      FROM
        credit_note_items AS ci
      WHERE
        ci.credit_note_id = cn.id
    ) - cn.precise_coupons_adjustment_amount_cents
  )::bigint AS sub_total_excluding_taxes_amount_cents,
  cn.balance_amount_cents,
  cn.credit_amount_cents,
  cn.refund_amount_cents,
  cn.coupons_adjustment_amount_cents,
  cn.taxes_rate,
  cn.created_at,
  cn.updated_at,
  cn.refunded_at,
  (
    SELECT
      json_agg (
        json_build_object (
          'lago_id',
          ci.id,
          'amount_cents',
          ci.amount_cents,
          'amount_currency',
          ci.amount_currency,
          'lago_fee_id',
          ci.fee_id
        )
      )
    FROM
      credit_note_items AS ci
    WHERE
      ci.credit_note_id = cn.id
  ) AS items,
  (
    SELECT
      json_agg (
        json_build_object (
          'lago_id',
          ed.id,
          'error_code',
          ed.error_code,
          'details',
          ed.details
        )
      )
    FROM
      error_details AS ed
    WHERE
      ed.owner_id = cn.id
  ) AS error_details
FROM
  credit_notes AS cn;
