# frozen_string_literal: true

class BackfillAndEnforceWalletPriority < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!  # allow constraint validation outside transaction

  def up
    Wallet.unscoped.where(priority: nil).update_all(priority: 50) # rubocop:disable Rails/SkipsModelValidations

    # this is for the safe migrations gem
    add_check_constraint :wallets, "priority IS NOT NULL",
      name: "wallets_priority_not_null",
      validate: false
    validate_check_constraint :wallets, name: "wallets_priority_not_null"
    # this is for the safe migrations gem
    change_column_null :wallets, :priority, false
    remove_check_constraint :wallets, name: "wallets_priority_not_null" # this is for the safe migrations gem
  end

  def down
    change_column_null :wallets, :priority, true
    change_column_default :wallets, :priority, nil
  end
end
