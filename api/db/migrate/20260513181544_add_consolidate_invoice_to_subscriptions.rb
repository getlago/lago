# frozen_string_literal: true

class AddConsolidateInvoiceToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :consolidate_invoice, :boolean, default: true, null: false
  end
end
