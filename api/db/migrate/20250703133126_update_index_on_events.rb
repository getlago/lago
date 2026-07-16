# frozen_string_literal: true

class UpdateIndexOnEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      remove_index :events,
        column: [:organization_id, :timestamp],
        algorithm: :concurrently,
        if_exists: true

      add_index :events,
        [:external_subscription_id, :organization_id, :code, :timestamp],
        algorithm: :concurrently,
        name: "idx_events_on_external_sub_id_and_org_id_and_code_and_timestamp",
        using: :btree,
        if_not_exists: true,
        where: "deleted_at IS NULL"
    end
  end

  def down
    safety_assured do
      remove_index :events,
        column: [:external_subscription_id, :organization_id, :code, :timestamp],
        algorithm: :concurrently,
        if_exists: true

      add_index :events,
        [:organization_id, :timestamp],
        algorithm: :concurrently,
        using: :btree,
        if_not_exists: true,
        where: "deleted_at IS NULL"
    end
  end
end
