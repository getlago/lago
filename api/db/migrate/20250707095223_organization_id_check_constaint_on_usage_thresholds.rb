# frozen_string_literal: true

class OrganizationIdCheckConstaintOnUsageThresholds < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :usage_thresholds,
      "organization_id IS NOT NULL",
      name: "usage_thresholds_organization_id_not_null",
      validate: false
  end
end
