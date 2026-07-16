# frozen_string_literal: true

class AddIndexOnWebhooksObjectTypeObjectIdWebhookType < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :webhooks, [:object_type, :object_id, :webhook_type],
      name: "index_webhooks_on_object_type_and_object_id_and_webhook_type",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
