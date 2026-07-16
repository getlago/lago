# frozen_string_literal: true

class CreateExportsUsageThresholds < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_usage_thresholds
  end
end
