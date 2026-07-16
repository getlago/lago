# frozen_string_literal: true

class AddEInvoicingXmLtoInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :xml_file, :string
  end
end
