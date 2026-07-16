# frozen_string_literal: true

class CreateFixedChargesTaxes < ActiveRecord::Migration[8.0]
  def change
    create_table :fixed_charges_taxes, id: :uuid do |t|
      t.references :fixed_charge, type: :uuid, null: false, foreign_key: true
      t.references :tax, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true

      t.index [:fixed_charge_id, :tax_id], unique: true
      t.timestamps
    end
  end
end
