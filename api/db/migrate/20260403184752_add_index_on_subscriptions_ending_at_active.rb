# frozen_string_literal: true

class AddIndexOnSubscriptionsEndingAtActive < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :subscriptions, :ending_at,
      where: "status = 1 AND ending_at IS NOT NULL",
      name: "index_subscriptions_on_ending_at_active",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
