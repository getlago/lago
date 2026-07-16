# frozen_string_literal: true

class CreatePendingViesChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :pending_vies_checks, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid, index: true
      t.references :billing_entity, null: false, foreign_key: true, type: :uuid, index: true
      t.references :customer, null: false, foreign_key: true, type: :uuid, index: {unique: true}
      t.integer :attempts_count, default: 0, null: false
      t.datetime :last_attempt_at
      t.string :tax_identification_number
      t.string :last_error_type
      t.text :last_error_message

      t.timestamps
    end
  end
end
