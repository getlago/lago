# frozen_string_literal: true

class AddGinIndexesForPaymentFields < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :payments, "organization_id, provider_payment_id gin_trgm_ops", using: :gin, algorithm: :concurrently, if_not_exists: true
    add_index :payments, "organization_id, reference gin_trgm_ops", using: :gin, algorithm: :concurrently, if_not_exists: true
  end
end
