# frozen_string_literal: true

class AddOrganizationIdFkToAppliedUsageThresholds < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :applied_usage_thresholds, :organizations, validate: false
  end
end
