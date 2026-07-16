# frozen_string_literal: true

class AddEInvoicingXmlToCreditNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :credit_notes, :xml_file, :string
  end
end
