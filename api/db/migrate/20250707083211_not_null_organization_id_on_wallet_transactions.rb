# frozen_string_literal: true

class NotNullOrganizationIdOnWalletTransactions < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :wallet_transactions, name: "wallet_transactions_organization_id_null"
    change_column_null :wallet_transactions, :organization_id, false
    remove_check_constraint :wallet_transactions, name: "wallet_transactions_organization_id_null"
  end

  def down
    add_check_constraint :wallet_transactions, "organization_id IS NOT NULL", name: "wallet_transactions_organization_id_null", validate: false
    change_column_null :wallet_transactions, :organization_id, true
  end
end
