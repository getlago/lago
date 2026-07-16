# frozen_string_literal: true

class AddPresentationBreakdowns < ActiveRecord::Migration[8.0]
  def change
    create_table :presentation_breakdowns, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :fee, null: false, foreign_key: true, type: :uuid, index: {unique: true}

      t.jsonb :presentation_by, null: false, default: []
      t.decimal :units, precision: 30, scale: 10, null: false, default: 0.0

      t.timestamps
    end
  end
end
