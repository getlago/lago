# frozen_string_literal: true

class CreateUserDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :user_devices, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.string :fingerprint, null: false
      t.string :browser
      t.string :os
      t.string :device_type
      t.datetime :last_logged_at, null: false
      t.string :last_ip_address
      t.timestamps
    end
    add_index :user_devices, [:user_id, :fingerprint], unique: true
  end
end
