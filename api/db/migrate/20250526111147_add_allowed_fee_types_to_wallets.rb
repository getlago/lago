# frozen_string_literal: true

class AddAllowedFeeTypesToWallets < ActiveRecord::Migration[8.0]
  def change
    add_column :wallets, :allowed_fee_types, :string, array: true, null: false, default: []
  end
end
