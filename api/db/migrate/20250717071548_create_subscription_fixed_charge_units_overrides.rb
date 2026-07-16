# frozen_string_literal: true

class CreateSubscriptionFixedChargeUnitsOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_fixed_charge_units_overrides, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :billing_entity, null: false, foreign_key: true, type: :uuid
      t.references :subscription, null: false, foreign_key: true, type: :uuid
      t.references :fixed_charge, null: false, foreign_key: true, type: :uuid

      t.decimal :units, precision: 30, scale: 10, null: false, default: 0.0
      t.datetime :deleted_at, index: true

      t.index [:subscription_id, :fixed_charge_id],
        unique: true,
        where: "deleted_at IS NULL"

      t.timestamps
    end
  end
end
