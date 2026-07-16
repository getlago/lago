# frozen_string_literal: true

class AddEventsOrganizationTimestampIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :events,
      [:organization_id, :timestamp],
      order: {timestamp: :desc},
      where: "deleted_at IS NULL",
      name: "index_events_on_organization_id_and_timestamp",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
