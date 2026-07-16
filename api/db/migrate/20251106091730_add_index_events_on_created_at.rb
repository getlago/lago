# frozen_string_literal: true

class AddIndexEventsOnCreatedAt < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index(
      :events,
      :created_at,
      name: :index_events_on_created_at,
      where: "deleted_at IS NULL",
      algorithm: :concurrently,
      if_not_exists: true
    )
  end
end
