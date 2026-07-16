# frozen_string_literal: true

class CreateRecurringTransactionRulesInvoiceCustomSections < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_transaction_rules_invoice_custom_sections, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid, index: true
      t.references :recurring_transaction_rule, null: false, foreign_key: true, type: :uuid, index: true
      t.references :invoice_custom_section, null: false, foreign_key: true, type: :uuid, index: true

      t.timestamps

      t.index %i[recurring_transaction_rule_id invoice_custom_section_id],
        unique: true,
        name: "index_rtr_invoice_custom_sections_unique"
    end
  end
end
