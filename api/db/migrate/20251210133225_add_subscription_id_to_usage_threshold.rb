# frozen_string_literal: true

class AddSubscriptionIdToUsageThreshold < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_reference :usage_thresholds, :subscription,
        foreign_key: true,
        index: {algorithm: :concurrently},
        type: :uuid,
        if_not_exists: true
    end
  end
end
