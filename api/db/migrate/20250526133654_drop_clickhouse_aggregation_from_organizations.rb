# frozen_string_literal: true

class DropClickhouseAggregationFromOrganizations < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :organizations, :clickhouse_aggregation, :boolean, default: false, null: false
    end
  end
end
