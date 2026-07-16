# frozen_string_literal: true

class UpdateExportsInvoiceSettlementsToVersion2 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_invoice_settlements, version: 2, revert_to_version: 1
  end
end
