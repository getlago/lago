# frozen_string_literal: true

class RecreateSubscriptionFixedChargeUnitsOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_fixed_charge_units_overrides, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :subscription, null: false, foreign_key: true, type: :uuid
      t.references :fixed_charge, null: false, foreign_key: true, type: :uuid

      t.decimal :units, precision: 30, scale: 10, null: false, default: 0.0
      t.datetime :deleted_at, index: true

      t.index [:subscription_id, :fixed_charge_id],
        unique: true,
        where: "deleted_at IS NULL",
        name: "index_sub_fc_units_overrides_on_sub_id_and_fc_id"

      t.check_constraint "units >= 0",
        name: "sub_fc_units_overrides_units_non_negative"

      t.timestamps
    end
  end
end
