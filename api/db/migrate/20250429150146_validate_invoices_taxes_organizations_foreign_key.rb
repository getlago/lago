# frozen_string_literal: true

class ValidateInvoicesTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :invoices_taxes, :organizations
  end
end
