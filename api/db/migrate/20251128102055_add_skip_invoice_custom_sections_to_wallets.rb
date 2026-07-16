# frozen_string_literal: true

class AddSkipInvoiceCustomSectionsToWallets < ActiveRecord::Migration[8.0]
  def change
    add_column :wallets, :skip_invoice_custom_sections, :boolean, default: false, null: false
  end
end
