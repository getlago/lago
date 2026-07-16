# frozen_string_literal: true

class UpdateIndexOnCachedAggregations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index(
        :cached_aggregations,
        [:event_transaction_id, :external_subscription_id, :charge_id, :timestamp],
        include: [:organization_id, :grouped_by],
        name: :idx_aggregation_lookup_with_transaction_id,
        algorithm: :concurrently
      )
    end
  end
end
