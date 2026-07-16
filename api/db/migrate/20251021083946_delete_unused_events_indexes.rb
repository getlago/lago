# frozen_string_literal: true

class DeleteUnusedEventsIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :events, name: :index_events_on_external_subscription_id_with_included, if_exists: true, algorithm: :concurrently
    remove_index :events, name: :index_events_on_properties, if_exists: true, algorithm: :concurrently
    remove_index :events, name: :index_events_on_customer_id, if_exists: true, algorithm: :concurrently
    remove_index :events, name: :index_events_on_deleted_at, if_exists: true, algorithm: :concurrently
    remove_index :events, name: :index_events_on_external_subscription_id_precise_amount, if_exists: true, algorithm: :concurrently
  end
end
