# frozen_string_literal: true

class AddCodeToWallets < ActiveRecord::Migration[8.0]
  def change
    add_column :wallets, :code, :string
  end
end
