# frozen_string_literal: true

class ValidateUsageThresholdsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :usage_thresholds, :organizations
  end
end
