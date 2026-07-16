# frozen_string_literal: true

class ChangeIndexesForUsageThresholds < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :usage_thresholds,
      name: "idx_on_amount_cents_plan_id_recurring_888044d66b",
      column: %w[amount_cents plan_id recurring],
      unique: true,
      where: "(deleted_at IS NULL)",
      algorithm: :concurrently,
      if_exists: true

    remove_index :usage_thresholds,
      name: "index_usage_thresholds_on_plan_id_and_recurring",
      column: %w[plan_id recurring],
      unique: true,
      where: "((recurring IS TRUE) AND (deleted_at IS NULL))",
      algorithm: :concurrently,
      if_exists: true

    change_column_null :usage_thresholds, :plan_id, true

    add_index :usage_thresholds, %w[amount_cents plan_id recurring],
      unique: true,
      where: "deleted_at IS NULL AND plan_id IS NOT NULL",
      name: "idx_usage_thresholds_on_amount_plan_recurring",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :usage_thresholds, %w[amount_cents subscription_id recurring],
      unique: true,
      where: "deleted_at IS NULL AND subscription_id IS NOT NULL",
      name: "idx_usage_thresholds_on_amount_subscription_recurring",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :usage_thresholds, %w[plan_id recurring],
      unique: true,
      where: "recurring IS TRUE AND deleted_at IS NULL AND plan_id IS NOT NULL",
      name: "idx_usage_thresholds_plan_recurring",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :usage_thresholds, %w[subscription_id recurring],
      unique: true,
      where: "recurring IS TRUE AND deleted_at IS NULL AND subscription_id IS NOT NULL",
      name: "idx_usage_thresholds_subscription_recurring",
      algorithm: :concurrently,
      if_not_exists: true

    safety_assured do
      add_check_constraint :usage_thresholds,
        "(plan_id IS NOT NULL) != (subscription_id IS NOT NULL)",
        name: "usage_thresholds_check_exactly_one_parent",
        validate: true,
        if_not_exists: true
    end
  end
end
