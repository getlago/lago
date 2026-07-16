# frozen_string_literal: true

class NotNullOrganizationIdOnAddOnsTaxes < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :add_ons_taxes, name: "add_ons_taxes_organization_id_null"
    change_column_null :add_ons_taxes, :organization_id, false
    remove_check_constraint :add_ons_taxes, name: "add_ons_taxes_organization_id_null"
  end

  def down
    add_check_constraint :add_ons_taxes, "organization_id IS NOT NULL", name: "add_ons_taxes_organization_id_null", validate: false
    change_column_null :add_ons_taxes, :organization_id, true
  end
end
