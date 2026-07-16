# frozen_string_literal: true

class AddIndexOnSubscriptionAtAndCreatedAtAndIdToSubscriptions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index(
        :subscriptions,
        [:organization_id, :subscription_at, :created_at, :id],
        order: {subscription_at: "DESC NULLS LAST", created_at: :desc},
        name: :idx_on_organization_id_subscription_at_created_at_id,
        algorithm: :concurrently
      )
    end
  end
end
