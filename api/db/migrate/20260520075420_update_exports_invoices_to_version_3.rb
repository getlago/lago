# frozen_string_literal: true

class UpdateExportsInvoicesToVersion3 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_invoices, version: 3, revert_to_version: 2
  end
end
