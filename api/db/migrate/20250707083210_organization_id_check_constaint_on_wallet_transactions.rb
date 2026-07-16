# frozen_string_literal: true

class OrganizationIdCheckConstaintOnWalletTransactions < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :wallet_transactions,
      "organization_id IS NOT NULL",
      name: "wallet_transactions_organization_id_null",
      validate: false
  end
end
