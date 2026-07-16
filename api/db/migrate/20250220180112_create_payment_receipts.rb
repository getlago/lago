# frozen_string_literal: true

class CreatePaymentReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_receipts, id: :uuid do |t|
      t.string :number, null: false
      t.references :payment, null: false, foreign_key: true, index: {unique: true}, type: :uuid
      t.references :organization, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
