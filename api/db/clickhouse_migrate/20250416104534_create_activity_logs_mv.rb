# frozen_string_literal: false

class CreateActivityLogsMv < ActiveRecord::Migration[7.0]
  def change
    sql = <<-SQL
      SELECT
        organization_id,
        user_id,
        api_key_id,
        external_customer_id,
        external_subscription_id,
        activity_id,
        resource_id,
        resource_type,
        activity_object,
        activity_object_changes,
        activity_type,
        activity_source,
        logged_at,
        created_at
      FROM activity_logs_queue
    SQL

    create_view :activity_logs_mv, materialized: true, as: sql, to: "activity_logs"
  end
end
