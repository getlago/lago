# frozen_string_literal: true

class AddOrganizationIdFkToWallets < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :wallets, :organizations, validate: false
  end
end
