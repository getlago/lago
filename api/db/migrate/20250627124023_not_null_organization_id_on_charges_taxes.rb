# frozen_string_literal: true

class NotNullOrganizationIdOnChargesTaxes < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :charges_taxes, name: "charges_taxes_organization_id_null"
    change_column_null :charges_taxes, :organization_id, false
    remove_check_constraint :charges_taxes, name: "charges_taxes_organization_id_null"
  end

  def down
    add_check_constraint :charges_taxes, "organization_id IS NOT NULL", name: "charges_taxes_organization_id_null", validate: false
    change_column_null :charges_taxes, :organization_id, true
  end
end
