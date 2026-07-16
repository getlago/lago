# frozen_string_literal: true

class FixPrivilegeIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :entitlement_privileges, %w[code entitlement_feature_id],
      name: :idx_privileges_code_unique_per_feature,
      unique: true,
      algorithm: :concurrently,
      if_exists: true

    add_index :entitlement_privileges, %w[code entitlement_feature_id],
      name: "idx_privileges_code_unique_per_feature",
      unique: true,
      where: "deleted_at IS NULL",
      algorithm: :concurrently
  end
end
