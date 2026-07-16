# frozen_string_literal: true

class AddDeletedAtToTaxesUniqueCodeIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :taxes, [:code, :organization_id],
      unique: true,
      where: "deleted_at IS NULL",
      name: "idx_unique_tax_code_per_organization",
      algorithm: :concurrently,
      if_not_exists: true

    remove_index :taxes, [:code, :organization_id],
      name: "index_taxes_on_code_and_organization_id",
      unique: true,
      algorithm: :concurrently,
      if_exists: true
  end
end
