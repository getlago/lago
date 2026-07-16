# frozen_string_literal: true

class NotNullOrganizationIdOnUsageThresholds < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :usage_thresholds, name: "usage_thresholds_organization_id_not_null"
    change_column_null :usage_thresholds, :organization_id, false
    remove_check_constraint :usage_thresholds, name: "usage_thresholds_organization_id_not_null"
  end

  def down
    add_check_constraint :usage_thresholds, "organization_id IS NOT NULL", name: "usage_thresholds_organization_id_not_null", validate: false
    change_column_null :usage_thresholds, :organization_id, true
  end
end
