# frozen_string_literal: true

class AddEventsOrganizationCreatedAtIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :events,
      [:organization_id, :created_at],
      order: {created_at: :desc},
      where: "deleted_at IS NULL",
      name: "index_events_on_organization_id_and_created_at",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
