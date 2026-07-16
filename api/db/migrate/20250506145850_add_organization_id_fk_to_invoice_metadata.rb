# frozen_string_literal: true

class AddOrganizationIdFkToInvoiceMetadata < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :invoice_metadata, :organizations, validate: false
  end
end
