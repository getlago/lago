# frozen_string_literal: true

class AddOrganizationIdToWallets < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :wallets, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
