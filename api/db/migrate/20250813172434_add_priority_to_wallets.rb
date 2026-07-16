# frozen_string_literal: true

class AddPriorityToWallets < ActiveRecord::Migration[8.0]
  def change
    add_column :wallets, :priority, :integer, default: 50
  end
end
