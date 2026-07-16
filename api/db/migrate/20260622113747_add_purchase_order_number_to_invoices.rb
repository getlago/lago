# frozen_string_literal: true

class AddPurchaseOrderNumberToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :purchase_order_number, :string
  end
end
