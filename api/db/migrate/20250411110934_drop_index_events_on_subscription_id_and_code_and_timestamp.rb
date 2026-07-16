# frozen_string_literal: true

class DropIndexEventsOnSubscriptionIdAndCodeAndTimestamp < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :events, name: :index_events_on_subscription_id_and_code_and_timestamp, algorithm: :concurrently, if_exists: true
  end
end
