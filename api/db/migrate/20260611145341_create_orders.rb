# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_enum :order_status, %w[created executed]
    create_enum :order_execution_mode, %w[execute_in_lago order_only]

    create_table :orders, id: :uuid do |t|
      t.references :organization,
        null: false,
        foreign_key: true,
        index: false, # covered by the composite unique indexes below
        type: :uuid
      t.references :customer,
        null: false,
        foreign_key: true,
        type: :uuid
      t.references :order_form,
        null: false,
        foreign_key: true,
        index: {unique: true},
        type: :uuid

      t.string :number, null: false
      t.integer :sequential_id, null: false

      t.enum :status,
        enum_type: :order_status,
        null: false,
        default: "created"
      t.enum :execution_mode, enum_type: :order_execution_mode

      t.datetime :execute_at
      t.datetime :executed_at

      t.timestamps

      t.check_constraint "sequential_id > 0",
        name: "orders_constraint_sequential_id_positive"
      t.index [:organization_id, :sequential_id],
        unique: true,
        name: "index_unique_orders_on_organization_sequential_id"
      t.index [:organization_id, :number],
        unique: true,
        name: "index_unique_orders_on_organization_number"
      t.index [:organization_id, :status]
      t.index [:organization_id, :created_at]
    end
  end
end
