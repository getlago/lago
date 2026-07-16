# frozen_string_literal: true

class AddSkipInvoiceCustomSectionsFlags < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :skip_invoice_custom_sections, :boolean, default: false, null: false
    add_column :recurring_transaction_rules, :skip_invoice_custom_sections, :boolean, default: false, null: false
    add_column :wallet_transactions, :skip_invoice_custom_sections, :boolean, default: false, null: false
  end
end
