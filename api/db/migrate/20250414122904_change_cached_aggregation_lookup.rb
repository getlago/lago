# frozen_string_literal: true

class ChangeCachedAggregationLookup < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_index(
        :cached_aggregations,
        [:external_subscription_id, :charge_id, :timestamp],
        include: [:organization_id, :grouped_by],
        name: :idx_aggregation_lookup,
        algorithm: :concurrently
      )
    end

    remove_index :cached_aggregations, name: :index_timestamp_filter_lookup
  end
end
