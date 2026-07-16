# frozen_string_literal: true

class CreatePaymentIntents < ActiveRecord::Migration[7.2]
  def change
    create_table :payment_intents, id: :uuid do |t|
      t.references :invoice, null: false, index: true, type: :uuid
      t.references :organization, null: false, index: true, type: :uuid
      t.string :payment_url
      t.integer :status, default: 0, null: false
      t.datetime :expires_at, null: false

      t.timestamps

      t.index ["invoice_id", "status"], where: "(status = 0)", unique: true
    end
  end
end
