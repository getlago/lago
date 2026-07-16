SELECT
  ins.id AS lago_id,
  ins.organization_id,
  ins.billing_entity_id AS lago_billing_entity_id,
  ins.target_invoice_id AS lago_target_invoice_id,
  ins.settlement_type,
  ins.source_payment_id AS lago_source_payment_id,
  ins.source_credit_note_id AS lago_source_credit_note_id,
  ins.amount_cents,
  ins.amount_currency,
  ins.created_at,
  ins.updated_at
FROM invoice_settlements AS ins;
