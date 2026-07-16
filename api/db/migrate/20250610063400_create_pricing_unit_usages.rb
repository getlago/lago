# frozen_string_literal: true

class CreatePricingUnitUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :pricing_unit_usages, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :fee, null: false, foreign_key: true, type: :uuid
      t.references :pricing_unit, null: false, foreign_key: true, type: :uuid

      t.string :short_name, null: false
      t.bigint :amount_cents, null: false
      t.decimal :precise_amount_cents, precision: 40, scale: 15, default: 0.0, null: false
      t.bigint :unit_amount_cents, default: 0, null: false
      t.decimal :conversion_rate, precision: 40, scale: 15, default: 0.0, null: false

      t.timestamps
    end
  end
end
