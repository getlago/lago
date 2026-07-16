# frozen_string_literal: true

class AddOrganizationIdFkToInvoicesTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :invoices_taxes, :organizations, validate: false
  end
end
