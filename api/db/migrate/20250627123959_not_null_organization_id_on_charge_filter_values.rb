# frozen_string_literal: true

class NotNullOrganizationIdOnChargeFilterValues < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :charge_filter_values, name: "charge_filter_values_organization_id_null"
    change_column_null :charge_filter_values, :organization_id, false
    remove_check_constraint :charge_filter_values, name: "charge_filter_values_organization_id_null"
  end

  def down
    add_check_constraint :charge_filter_values, "organization_id IS NOT NULL", name: "charge_filter_values_organization_id_null", validate: false
    change_column_null :charge_filter_values, :organization_id, true
  end
end
