# frozen_string_literal: true

class AddIndexOnWebhooksOrganizationEndpointTypeUpdated < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :webhooks,
        [:organization_id, :webhook_endpoint_id, :webhook_type, :updated_at],
        name: :index_webhooks_for_query,
        if_not_exists: true,
        algorithm: :concurrently
    end
  end
end
