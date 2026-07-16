# frozen_string_literal: true

class CreateExportsInvoiceSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_invoice_subscriptions
  end
end
