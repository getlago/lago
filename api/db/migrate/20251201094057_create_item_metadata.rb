# frozen_string_literal: true

class CreateItemMetadata < ActiveRecord::Migration[8.0]
  def change
    create_table :item_metadata, id: :uuid do |t|
      t.references :organization,
        null: false,
        type: :uuid,
        foreign_key: {on_delete: :cascade},
        comment: "Reference to the organization"
      t.string :owner_type, null: false, comment: "Polymorphic owner type"
      t.uuid :owner_id, null: false, comment: "Polymorphic owner id"
      t.jsonb :value, null: false, default: {}, comment: "item_metadata key-value pairs"
      t.timestamps

      t.check_constraint "jsonb_typeof(value) = 'object'", name: "item_metadata_value_must_be_json_object"

      t.index [:owner_type, :owner_id], unique: true
      t.index :value, name: "index_item_metadata_on_value", using: :gin
    end
  end
end
