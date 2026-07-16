# frozen_string_literal: true

class AddPaymentReceiptCounterToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :payment_receipt_counter, :bigint, default: 0, null: false
  end
end
