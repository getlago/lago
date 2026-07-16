# frozen_string_literal: false

class CreateSecurityLogsMv < ActiveRecord::Migration[8.0]
  def up
    sql = <<-SQL
      SELECT
        organization_id,
        user_id,
        api_key_id,
        log_id,
        log_type,
        log_event,
        device_info,
        resources,
        logged_at,
        created_at
      FROM security_logs_queue
    SQL

    create_view :security_logs_mv, materialized: true, as: sql, to: "security_logs"
  end

  def down
    drop_table :security_logs_mv, if_exists: true
  end
end
