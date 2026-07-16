# frozen_string_literal: true

class RemoveEventsUnusedIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index(
      :events,
      name: :idx_events_on_external_sub_id_and_org_id_and_code_and_timestamp,
      algorithm: :concurrently,
      if_exists: true
    )
  end
end
