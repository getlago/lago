# frozen_string_literal: true

class CreateExportsInvoiceSettlements < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_invoice_settlements
  end
end
