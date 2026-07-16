SELECT
  wtc.id AS lago_id,
  wtc.organization_id,
  wtc.inbound_wallet_transaction_id AS lago_inbound_wallet_transaction_id,
  wtc.outbound_wallet_transaction_id AS lago_outbound_wallet_transaction_id,
  wtc.consumed_amount_cents,
  wtc.created_at,
  wtc.updated_at
FROM wallet_transaction_consumptions AS wtc;
