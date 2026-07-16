# frozen_string_literal: true

class ValidateAppliedUsageThresholdsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :applied_usage_thresholds, :organizations
  end
end
