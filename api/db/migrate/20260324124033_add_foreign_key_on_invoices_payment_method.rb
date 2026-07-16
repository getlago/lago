# frozen_string_literal: true

class AddForeignKeyOnInvoicesPaymentMethod < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :invoices, :payment_methods, column: :payment_method_id, validate: false
  end
end
