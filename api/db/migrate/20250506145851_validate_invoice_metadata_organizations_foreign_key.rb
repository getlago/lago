# frozen_string_literal: true

class ValidateInvoiceMetadataOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :invoice_metadata, :organizations
  end
end
