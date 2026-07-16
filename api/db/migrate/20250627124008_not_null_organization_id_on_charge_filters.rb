# frozen_string_literal: true

class NotNullOrganizationIdOnChargeFilters < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :charge_filters, name: "charge_filters_organization_id_null"
    change_column_null :charge_filters, :organization_id, false
    remove_check_constraint :charge_filters, name: "charge_filters_organization_id_null"
  end

  def down
    add_check_constraint :charge_filters, "organization_id IS NOT NULL", name: "charge_filters_organization_id_null", validate: false
    change_column_null :charge_filters, :organization_id, true
  end
end
