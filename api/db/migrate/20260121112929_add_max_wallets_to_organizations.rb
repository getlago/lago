# frozen_string_literal: true

class AddMaxWalletsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :max_wallets, :integer, null: true
  end
end
