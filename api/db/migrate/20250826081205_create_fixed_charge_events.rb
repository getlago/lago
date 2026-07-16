# frozen_string_literal: true

class CreateFixedChargeEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :fixed_charge_events, id: :uuid do |t|
      t.belongs_to :organization, null: false, foreign_key: true, type: :uuid
      t.belongs_to :subscription, null: false, foreign_key: true, type: :uuid
      t.belongs_to :fixed_charge, null: false, foreign_key: true, type: :uuid

      t.decimal :units, precision: 30, scale: 10, null: false, default: 0.0
      t.datetime :timestamp
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
