# frozen_string_literal: true

class RemoveOldIndexOnCachedAggregations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      remove_index :cached_aggregations, name: :idx_on_timestamp_charge_id_external_subscription_id
      remove_index :cached_aggregations, name: :index_cached_aggregations_on_organization_id
    end
  end

  def down
    safety_assured do
      add_index :cached_aggregations,
        %i[timestamp charge_id external_subscription_id],
        algorithm: :concurrently,
        name: :idx_on_timestamp_charge_id_external_subscription_id

      add_index :cached_aggregations,
        %i[organization_id],
        algorithm: :concurrently,
        name: :index_cached_aggregations_on_organization_id
    end
  end
end
