# frozen_string_literal: true

class AddGinIndexOnSubscriptionsExternalId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :subscriptions, "organization_id, external_id gin_trgm_ops", using: :gin, algorithm: :concurrently, if_not_exists: true
  end
end
