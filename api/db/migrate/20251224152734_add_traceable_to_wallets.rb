# frozen_string_literal: true

class AddTraceableToWallets < ActiveRecord::Migration[8.0]
  def change
    add_column :wallets, :traceable, :boolean, default: false, null: false
  end
end
