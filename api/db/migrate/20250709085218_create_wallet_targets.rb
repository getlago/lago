# frozen_string_literal: true

class CreateWalletTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :wallet_targets, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid, index: true
      t.references :wallet, null: false, foreign_key: true, type: :uuid, index: true
      t.references :billable_metric, null: false, foreign_key: true, type: :uuid, index: true

      t.timestamps
    end
  end
end
