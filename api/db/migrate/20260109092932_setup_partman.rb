# frozen_string_literal: true

class SetupPartman < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      unless pg_extension_present?("pg_partman")
        Rails.logger.debug "pg_partman extension is not available on this PostgreSQL server, skipping..."
        return
      end

      execute <<~SQL
        CREATE SCHEMA IF NOT EXISTS partman;
        CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;
      SQL
    end
  end
end
