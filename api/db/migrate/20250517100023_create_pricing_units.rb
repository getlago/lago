# frozen_string_literal: true

class CreatePricingUnits < ActiveRecord::Migration[7.2]
  def change
    create_table :pricing_units, id: :uuid do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :short_name, null: false
      t.text :description

      t.references :organization, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :pricing_units, [:code, :organization_id], unique: true
  end
end
