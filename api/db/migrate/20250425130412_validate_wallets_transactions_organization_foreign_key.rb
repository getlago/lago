# frozen_string_literal: true

class ValidateWalletsTransactionsOrganizationForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :wallet_transactions, :organizations
  end
end
