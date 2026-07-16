# frozen_string_literal: true

class DropIndexEventsOnSubscriptionId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :events, name: :index_events_on_subscription_id, algorithm: :concurrently, if_exists: true
  end
end
