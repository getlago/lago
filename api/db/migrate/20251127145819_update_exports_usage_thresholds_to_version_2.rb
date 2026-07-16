# frozen_string_literal: true

class UpdateExportsUsageThresholdsToVersion2 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_usage_thresholds, version: 2, revert_to_version: 1
  end
end
