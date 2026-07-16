# frozen_string_literal: true

class OrganizationIdCheckConstaintOnWallets < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :wallets,
      "organization_id IS NOT NULL",
      name: "wallets_organization_id_null",
      validate: false
  end
end
