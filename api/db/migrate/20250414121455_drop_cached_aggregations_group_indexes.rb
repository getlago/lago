# frozen_string_literal: true

class DropCachedAggregationsGroupIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :cached_aggregations, name: :index_cached_aggregations_on_group_id
    remove_index :cached_aggregations, name: :index_timestamp_group_lookup
  end
end
