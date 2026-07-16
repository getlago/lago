# frozen_string_literal: true

class AddWebhooksCleanupIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :webhooks,
      :updated_at,
      name: :index_webhooks_on_updated_at_for_cleanup,
      algorithm: :concurrently,
      include: [:id],
      if_not_exists: true
  end
end
