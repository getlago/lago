# frozen_string_literal: true

class CreateInvoiceSettlements < ActiveRecord::Migration[8.0]
  def change
    create_enum :invoice_settlement_settlement_type, ["payment", "credit_note"]

    create_table :invoice_settlements, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :billing_entity, null: false, foreign_key: true, type: :uuid
      t.references :target_invoice, null: false, foreign_key: {to_table: :invoices}, type: :uuid
      t.enum :settlement_type, enum_type: :invoice_settlement_settlement_type, null: false

      t.references :source_payment, foreign_key: {to_table: :payments}, type: :uuid
      t.references :source_credit_note, foreign_key: {to_table: :credit_notes}, type: :uuid

      t.bigint :amount_cents, null: false
      t.string :amount_currency, null: false

      t.timestamps
    end
  end
end
