# frozen_string_literal: true

class NotNullOrganizationIdOnCustomersTaxes < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :customers_taxes, name: "customers_taxes_organization_id_null"
    change_column_null :customers_taxes, :organization_id, false
    remove_check_constraint :customers_taxes, name: "customers_taxes_organization_id_null"
  end

  def down
    add_check_constraint :customers_taxes, "organization_id IS NOT NULL", name: "customers_taxes_organization_id_null", validate: false
    change_column_null :customers_taxes, :organization_id, true
  end
end
