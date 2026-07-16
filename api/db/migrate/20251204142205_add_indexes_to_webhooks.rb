# frozen_string_literal: true

class AddIndexesToWebhooks < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index(
      :webhooks,
      [:webhook_endpoint_id, :updated_at, :created_at],
      name: :index_webhooks_on_endpoint_and_timestamps,
      algorithm: :concurrently
    )

    add_index(
      :webhooks,
      [:webhook_endpoint_id, :status, :updated_at],
      name: :index_webhooks_on_endpoint_status_and_timestamps,
      algorithm: :concurrently
    )
  end
end
