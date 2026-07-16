# frozen_string_literal: true

class AddIndexOnCachedAggregationCreatedAt < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :cached_aggregations, name: :idx_aggregation_lookup_with_transaction_id, if_exists: true, algorithm: :concurrently

    safety_assured do
      add_index(
        :cached_aggregations,
        [:organization_id, :external_subscription_id, :charge_id, :timestamp, :created_at],
        order: {timestamp: :desc, created_at: :desc},
        include: [:grouped_by, :charge_filter_id, :event_transaction_id],
        name: :idx_cached_aggregation_filtered_lookup,
        algorithm: :concurrently
      )
    end
  end

  def down
    safety_assured do
      add_index(
        :cached_aggregations,
        [:event_transaction_id, :external_subscription_id, :charge_id, :timestamp],
        include: [:organization_id, :grouped_by],
        name: :idx_aggregation_lookup_with_transaction_id,
        algorithm: :concurrently
      )

      remove_index :cached_aggregations, name: :idx_cached_agg_comprehensive, algorithm: :concurrently
    end
  end
end
