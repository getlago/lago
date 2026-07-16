# frozen_string_literal: true

class AddPresentationBreakdownsToCachedAggregations < ActiveRecord::Migration[8.0]
  def change
    add_column :cached_aggregations, :presentation_breakdowns, :jsonb, null: false, default: []
  end
end
