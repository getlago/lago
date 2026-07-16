# frozen_string_literal: true

class AddBillingEntityToWallets < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :wallets, :billing_entity, type: :uuid, null: true,
      index: {algorithm: :concurrently}
    add_foreign_key :wallets, :billing_entities, validate: false
  end
end
