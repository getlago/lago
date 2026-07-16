# frozen_string_literal: true

class CreatePaymentMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_methods, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :customer, type: :uuid, null: false, foreign_key: true
      t.references :payment_provider, type: :uuid, foreign_key: true
      t.references :payment_provider_customer, type: :uuid, foreign_key: true

      t.string :provider_method_id, null: false
      t.string :provider_method_type, null: true, index: true
      t.boolean :is_default, default: false, null: false
      t.datetime :deleted_at
      t.jsonb :details, null: false, default: {}

      t.timestamps

      t.index [:customer_id], where: "is_default = TRUE AND deleted_at IS NULL", name: "unique_default_payment_method_per_customer", unique: true
    end
  end
end
