# frozen_string_literal: true

class AddAcceptsWalletTargetToCharges < ActiveRecord::Migration[8.0]
  def change
    add_column :charges, :accepts_target_wallet, :boolean, default: false, null: false
  end
end
