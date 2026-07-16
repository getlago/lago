# frozen_string_literal: true

class AddCodeUniquenessIndexToBillingEntities < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :billing_entities, [:code, :organization_id],
      unique: true,
      where: "deleted_at IS NULL AND archived_at IS NULL",
      algorithm: :concurrently
  end
end
