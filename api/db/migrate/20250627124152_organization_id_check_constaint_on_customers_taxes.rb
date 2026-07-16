# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCustomersTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :customers_taxes,
      "organization_id IS NOT NULL",
      name: "customers_taxes_organization_id_null",
      validate: false
  end
end
