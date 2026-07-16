# frozen_string_literal: true

class CreateBillingEntitiesTaxes < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_entities_taxes, id: :uuid do |t|
      t.references :billing_entity, null: false, foreign_key: true, type: :uuid
      t.references :tax, null: false, foreign_key: true, type: :uuid

      t.index %i[billing_entity_id tax_id], unique: true

      t.timestamps
    end
  end
end
