# frozen_string_literal: true

class AddInAdvanceIndexToFees < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_index :fees,
      [:pay_in_advance_event_transaction_id, :charge_id],
      unique: true,
      name: :idx_pay_in_advance_duplication_guard_charge,
      where: "deleted_at IS NULL AND charge_filter_id IS NULL AND pay_in_advance_event_transaction_id IS NOT NULL AND pay_in_advance = true AND duplicated_in_advance = false",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :fees,
      [:pay_in_advance_event_transaction_id, :charge_id, :charge_filter_id],
      unique: true,
      name: :idx_pay_in_advance_duplication_guard_charge_filter,
      where: "deleted_at IS NULL AND charge_filter_id IS NOT NULL AND pay_in_advance_event_transaction_id IS NOT NULL AND pay_in_advance = true AND duplicated_in_advance = false",
      algorithm: :concurrently,
      if_not_exists: true

    remove_index :fees, name: :idx_on_pay_in_advance_event_transaction_id_charge_i_16302ca167
  end

  def down
    add_index :fees,
      [:pay_in_advance_event_transaction_id, :charge_id, :charge_filter_id],
      unique: true,
      name: :idx_on_pay_in_advance_event_transaction_id_charge_i_16302ca167,
      where: "created_at > '2025-01-21 00:00:00'::timestamp without time zone AND pay_in_advance_event_transaction_id IS NOT NULL AND pay_in_advance = true",
      algorithm: :concurrently,
      if_not_exists: true

    remove_index :fees, name: :idx_pay_in_advance_duplication_guard_charge
    remove_index :fees, name: :idx_pay_in_advance_duplication_guard_charge_filter
  end
end
