# frozen_string_literal: false

class CreateApiLogsMv < ActiveRecord::Migration[7.0]
  def change
    sql = <<-SQL
      SELECT
        request_id,
        organization_id,
        api_key_id,
        api_version,
        client,
        request_body,
        request_response,
        request_path,
        request_origin,
        http_method,
        http_status,
        logged_at,
        created_at
      FROM api_logs_queue
    SQL

    create_view :api_logs_mv, materialized: true, as: sql, to: "api_logs"
  end
end
