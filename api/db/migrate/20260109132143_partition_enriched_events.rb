# frozen_string_literal: true

class PartitionEnrichedEvents < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      unless pg_extension_present?("pg_partman")
        Rails.logger.debug "pg_partman extension is not available on this PostgreSQL server, skipping..."
        return
      end

      execute <<~SQL
        SELECT partman.create_parent(
          p_parent_table := 'public.enriched_events',
          p_control := 'timestamp',
          p_interval := '1 month',
          p_type := 'range',
          p_premake := 3,                    -- Create 3 months ahead
          p_start_partition := '2024-12-01'
        )
      SQL

      execute <<~SQL
        UPDATE partman.part_config
        SET infinite_time_partitions = true,
            retention = '14 months', -- Handle yearly plan with large grace periods
            retention_keep_table = true
        WHERE parent_table = 'public.enriched_events';
      SQL
    end
  end
end
