# frozen_string_literal: true

class AddPrivilegeRemoval < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      # Adding foreign key blocks writes, but the feature isn't released yet. Table is empty.
      add_reference :entitlement_subscription_feature_removals, :entitlement_privilege,
        foreign_key: true,
        index: {algorithm: :concurrently},
        type: :uuid,
        if_not_exists: true
    end

    remove_index :entitlement_subscription_feature_removals,
      name: "idx_on_subscription_id_entitlement_feature_id_02bee9883b",
      column: [:subscription_id, :entitlement_feature_id],
      unique: true,
      where: "(deleted_at IS NULL)",
      algorithm: :concurrently,
      if_exists: true

    change_column_null :entitlement_subscription_feature_removals, :entitlement_feature_id, true

    add_index :entitlement_subscription_feature_removals, [:subscription_id, :entitlement_feature_id],
      unique: true,
      where: "deleted_at IS NULL",
      name: "idx_unique_feature_removal_per_subscription",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :entitlement_subscription_feature_removals, [:subscription_id, :entitlement_privilege_id],
      unique: true,
      where: "deleted_at IS NULL",
      name: "idx_unique_privilege_removal_per_subscription",
      algorithm: :concurrently,
      if_not_exists: true

    safety_assured do
      # Adding a check constraint, blocks reads and writes while every row is checked,
      # but the feature isn't released yet. Table is empty.
      add_check_constraint :entitlement_subscription_feature_removals,
        "(entitlement_feature_id IS NOT NULL) != (entitlement_privilege_id IS NOT NULL)",
        name: "check_exactly_one_feature_or_privilege_removal",
        validate: true,
        if_not_exists: true
    end
  end
end
