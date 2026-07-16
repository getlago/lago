# frozen_string_literal: true

class CreateAppliedPricingUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :applied_pricing_units, id: :uuid do |t|
      t.references :pricing_unit, null: false, foreign_key: true, type: :uuid
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :pricing_unitable, null: false, type: :uuid, polymorphic: true

      t.decimal :conversion_rate, precision: 40, scale: 15, default: "0.0", null: false

      t.timestamps
    end
  end
end
