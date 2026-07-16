# frozen_string_literal: true

class CreateIdempotencyRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :idempotency_records, id: :uuid do |t|
      t.binary :idempotency_key, null: false
      t.uuid :resource_id
      t.string :resource_type

      t.timestamps
    end

    add_index :idempotency_records, [:resource_type, :resource_id]
    add_index :idempotency_records, [:idempotency_key], unique: true
  end
end
