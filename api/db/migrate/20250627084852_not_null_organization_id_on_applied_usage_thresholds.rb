# frozen_string_literal: true

class NotNullOrganizationIdOnAppliedUsageThresholds < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :applied_usage_thresholds, name: "applied_usage_thresholds_organization_id_null"
    change_column_null :applied_usage_thresholds, :organization_id, false
    remove_check_constraint :applied_usage_thresholds, name: "applied_usage_thresholds_organization_id_null"
  end

  def down
    add_check_constraint :applied_usage_thresholds, "organization_id IS NOT NULL", name: "applied_usage_thresholds_organization_id_null", validate: false
    change_column_null :applied_usage_thresholds, :organization_id, true
  end
end
