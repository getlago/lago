# frozen_string_literal: true

# Given the fees table is large, this migration builds the new indexes under
# temporary names first, then drops the old ones, then renames.
# This keeps a unique constraint enforcing the guard at all times,
# avoiding a window where duplicate pay-in-advance fees could be inserted and
# later cause the concurrent build to fail and leave an INVALID index behind.
class UpdatePayInAdvanceDuplicationGuardIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  CHARGE_INDEX = :idx_pay_in_advance_duplication_guard_charge
  CHARGE_FILTER_INDEX = :idx_pay_in_advance_duplication_guard_charge_filter
  CHARGE_INDEX_NEW = :idx_pay_in_advance_duplication_guard_charge_new
  CHARGE_FILTER_INDEX_NEW = :idx_pay_in_advance_duplication_guard_charge_filter_new

  def up
    add_index :fees,
      [:pay_in_advance_event_transaction_id, :charge_id],
      unique: true,
      name: CHARGE_INDEX_NEW,
      where: "deleted_at IS NULL AND charge_filter_id IS NULL AND pay_in_advance_event_transaction_id IS NOT NULL AND pay_in_advance = true AND duplicated_in_advance = false AND original_fee_id IS NULL",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :fees,
      [:pay_in_advance_event_transaction_id, :charge_id, :charge_filter_id],
      unique: true,
      name: CHARGE_FILTER_INDEX_NEW,
      where: "deleted_at IS NULL AND charge_filter_id IS NOT NULL AND pay_in_advance_event_transaction_id IS NOT NULL AND pay_in_advance = true AND duplicated_in_advance = false AND original_fee_id IS NULL",
      algorithm: :concurrently,
      if_not_exists: true

    remove_index :fees, name: CHARGE_INDEX, if_exists: true, algorithm: :concurrently
    remove_index :fees, name: CHARGE_FILTER_INDEX, if_exists: true, algorithm: :concurrently

    safety_assured do
      execute "ALTER INDEX #{CHARGE_INDEX_NEW} RENAME TO #{CHARGE_INDEX}"
      execute "ALTER INDEX #{CHARGE_FILTER_INDEX_NEW} RENAME TO #{CHARGE_FILTER_INDEX}"
    end
  end

  def down
    add_index :fees,
      [:pay_in_advance_event_transaction_id, :charge_id],
      unique: true,
      name: CHARGE_INDEX_NEW,
      where: "deleted_at IS NULL AND charge_filter_id IS NULL AND pay_in_advance_event_transaction_id IS NOT NULL AND pay_in_advance = true AND duplicated_in_advance = false",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :fees,
      [:pay_in_advance_event_transaction_id, :charge_id, :charge_filter_id],
      unique: true,
      name: CHARGE_FILTER_INDEX_NEW,
      where: "deleted_at IS NULL AND charge_filter_id IS NOT NULL AND pay_in_advance_event_transaction_id IS NOT NULL AND pay_in_advance = true AND duplicated_in_advance = false",
      algorithm: :concurrently,
      if_not_exists: true

    remove_index :fees, name: CHARGE_INDEX, if_exists: true, algorithm: :concurrently
    remove_index :fees, name: CHARGE_FILTER_INDEX, if_exists: true, algorithm: :concurrently

    safety_assured do
      execute "ALTER INDEX #{CHARGE_INDEX_NEW} RENAME TO #{CHARGE_INDEX}"
      execute "ALTER INDEX #{CHARGE_FILTER_INDEX_NEW} RENAME TO #{CHARGE_FILTER_INDEX}"
    end
  end
end
