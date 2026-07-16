# frozen_string_literal: true

class DropCachedAggregationTimestampLookup < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :cached_aggregations, name: :index_timestamp_lookup
  end
end
