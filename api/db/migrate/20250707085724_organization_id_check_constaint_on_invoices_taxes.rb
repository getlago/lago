# frozen_string_literal: true

class OrganizationIdCheckConstaintOnInvoicesTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :invoices_taxes,
      "organization_id IS NOT NULL",
      name: "invoices_taxes_organization_id_null",
      validate: false
  end
end
