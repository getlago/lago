# frozen_string_literal: true

class OrganizationIdCheckConstaintOnAppliedUsageThresholds < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :applied_usage_thresholds,
      "organization_id IS NOT NULL",
      name: "applied_usage_thresholds_organization_id_null",
      validate: false
  end
end
