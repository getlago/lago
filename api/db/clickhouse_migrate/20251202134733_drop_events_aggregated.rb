# frozen_string_literal: true

class DropEventsAggregated < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute "DROP VIEW IF EXISTS events_aggregated_mv"
    end

    drop_table :events_aggregated
  end
end
