# frozen_string_literal: true

class NotNullOrganizationIdOnWallets < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :wallets, name: "wallets_organization_id_null"
    change_column_null :wallets, :organization_id, false
    remove_check_constraint :wallets, name: "wallets_organization_id_null"
  end

  def down
    add_check_constraint :wallets, "organization_id IS NOT NULL", name: "wallets_organization_id_null", validate: false
    change_column_null :wallets, :organization_id, true
  end
end
