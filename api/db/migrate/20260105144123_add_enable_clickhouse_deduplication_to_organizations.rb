# frozen_string_literal: true

class AddEnableClickhouseDeduplicationToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :clickhouse_deduplication_enabled, :boolean, default: false, null: false
  end
end
