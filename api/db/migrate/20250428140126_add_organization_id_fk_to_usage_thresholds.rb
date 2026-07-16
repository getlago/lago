# frozen_string_literal: true

class AddOrganizationIdFkToUsageThresholds < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :usage_thresholds, :organizations, validate: false
  end
end
