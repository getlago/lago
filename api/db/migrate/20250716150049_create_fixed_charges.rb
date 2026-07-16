# frozen_string_literal: true

class CreateFixedCharges < ActiveRecord::Migration[8.0]
  def change
    create_table :fixed_charges, id: :uuid do |t|
      t.belongs_to :organization, null: false, foreign_key: true, type: :uuid
      t.belongs_to :plan, null: false, foreign_key: true, type: :uuid
      t.belongs_to :add_on, null: false, foreign_key: true, type: :uuid
      t.belongs_to :parent, type: :uuid, index: true

      t.enum :charge_model, enum_type: "fixed_charge_charge_model", null: false, default: "standard"
      t.jsonb :properties, null: false, default: {}
      t.string :invoice_display_name
      t.boolean :pay_in_advance, default: false, null: false
      t.boolean :prorated, default: false, null: false
      t.decimal :units, precision: 30, scale: 10, null: false, default: 0.0
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
