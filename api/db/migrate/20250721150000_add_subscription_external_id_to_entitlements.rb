# frozen_string_literal: true

class AddSubscriptionExternalIdToEntitlements < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      # Adding foreign key blocks writes, but the feature isn't released yet. Table is empty.
      add_reference :entitlement_entitlements, :subscription,
        foreign_key: true,
        index: {algorithm: :concurrently},
        type: :uuid,
        if_not_exists: true
    end

    remove_index :entitlement_entitlements,
      name: "idx_on_entitlement_feature_id_plan_id_c45949ea26",
      column: %w[entitlement_feature_id plan_id],
      unique: true,
      where: "(deleted_at IS NULL)",
      algorithm: :concurrently,
      if_exists: true

    change_column_null :entitlement_entitlements, :plan_id, true

    add_index :entitlement_entitlements, %w[entitlement_feature_id plan_id],
      unique: true,
      where: "deleted_at IS NULL",
      name: "idx_unique_feature_per_plan",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :entitlement_entitlements, %w[entitlement_feature_id subscription_id],
      unique: true,
      where: "deleted_at IS NULL",
      name: "idx_unique_feature_per_subscription",
      algorithm: :concurrently,
      if_not_exists: true

    safety_assured do
      # Adding a check constraint key blocks reads and writes while every row is checked,
      # but the feature isn't released yet. Table is empty.
      add_check_constraint :entitlement_entitlements,
        "(plan_id IS NOT NULL) != (subscription_id IS NOT NULL)",
        name: "entitlement_check_exactly_one_parent",
        validate: true,
        if_not_exists: true
    end
  end
end
