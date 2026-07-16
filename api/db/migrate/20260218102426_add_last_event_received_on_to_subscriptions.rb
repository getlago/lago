# frozen_string_literal: true

class AddLastEventReceivedOnToSubscriptions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :subscriptions, :last_received_event_on, :date
    add_index :subscriptions, :last_received_event_on,
      name: "index_subscriptions_on_last_received_event_on",
      algorithm: :concurrently,
      if_not_exists: true
    # this will be dropped after we do the backfill after the OSS release
    add_index :subscriptions, :id,
      name: "index_subscriptions_on_last_received_event_on_null",
      where: "last_received_event_on IS NULL",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
