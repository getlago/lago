# frozen_string_literal: true

class CreateWalletsInvoiceCustomSections < ActiveRecord::Migration[8.0]
  def change
    create_table :wallets_invoice_custom_sections, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid, index: true
      t.references :wallet, null: false, foreign_key: true, type: :uuid, index: true
      t.references :invoice_custom_section, null: false, foreign_key: true, type: :uuid, index: true

      t.timestamps

      t.index %i[wallet_id invoice_custom_section_id],
        unique: true,
        name: "index_wallets_invoice_custom_sections_unique"
    end
  end
end
