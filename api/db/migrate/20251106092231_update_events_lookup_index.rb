# frozen_string_literal: true

class UpdateEventsLookupIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index(
        :events,
        %w[external_subscription_id organization_id code timestamp],
        include: [:properties],
        name: :idx_events_billing_lookup,
        where: "deleted_at IS NULL",
        algorithm: :concurrently,
        if_not_exists: true
      )
    end
  end
end
