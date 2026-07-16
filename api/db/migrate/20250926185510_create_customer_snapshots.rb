# frozen_string_literal: true

class CreateCustomerSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_snapshots, id: :uuid do |t|
      t.references :invoice, null: false, foreign_key: true, type: :uuid, index: false
      t.references :organization, null: false, foreign_key: true, type: :uuid

      t.string :display_name
      t.string :firstname
      t.string :lastname
      t.string :email
      t.string :phone
      t.string :url
      t.string :tax_identification_number
      t.string :applicable_timezone
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :zipcode
      t.string :country
      t.string :legal_name
      t.string :legal_number
      t.string :shipping_address_line1
      t.string :shipping_address_line2
      t.string :shipping_city
      t.string :shipping_state
      t.string :shipping_zipcode
      t.string :shipping_country

      t.datetime :deleted_at, index: true

      t.timestamps

      t.index :invoice_id,
        unique: true,
        where: "deleted_at IS NULL"
    end
  end
end
