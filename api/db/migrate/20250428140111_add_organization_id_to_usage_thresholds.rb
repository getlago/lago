# frozen_string_literal: true

class AddOrganizationIdToUsageThresholds < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :usage_thresholds, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
