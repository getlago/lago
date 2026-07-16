# frozen_string_literal: true

class AddGinIndexesForCustomerFields < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :customers, "organization_id, name gin_trgm_ops", using: :gin, where: "deleted_at IS NULL", algorithm: :concurrently, if_not_exists: true
    add_index :customers, "organization_id, email gin_trgm_ops", using: :gin, where: "deleted_at IS NULL", algorithm: :concurrently, if_not_exists: true
    add_index :customers, "organization_id, firstname gin_trgm_ops", using: :gin, where: "deleted_at IS NULL", algorithm: :concurrently, if_not_exists: true
    add_index :customers, "organization_id, lastname gin_trgm_ops", using: :gin, where: "deleted_at IS NULL", algorithm: :concurrently, if_not_exists: true
    add_index :customers, "organization_id, legal_name gin_trgm_ops", using: :gin, where: "deleted_at IS NULL", algorithm: :concurrently, if_not_exists: true
    add_index :customers, "organization_id, external_id gin_trgm_ops", using: :gin, where: "deleted_at IS NULL", algorithm: :concurrently, if_not_exists: true
  end
end
