# frozen_string_literal: true

class CreateOrderForms < ActiveRecord::Migration[8.0]
  def change
    create_enum :order_form_status, %w[generated signed expired voided]
    create_enum :order_form_void_reason, %w[manual expired invalid]

    create_table :order_forms, id: :uuid do |t|
      t.references :organization,
        null: false,
        foreign_key: true,
        index: false, # covered by the composite unique indexes below
        type: :uuid
      t.references :customer,
        null: false,
        foreign_key: true,
        type: :uuid
      t.references :quote_version,
        null: false,
        foreign_key: true,
        index: {unique: true},
        type: :uuid
      t.references :marked_as_signed_by_user,
        foreign_key: {to_table: :users},
        type: :uuid

      t.string :number, null: false
      t.integer :sequential_id, null: false

      t.enum :status,
        enum_type: :order_form_status,
        null: false,
        default: "generated"
      t.enum :void_reason, enum_type: :order_form_void_reason

      t.datetime :expires_at
      t.datetime :signed_at
      t.datetime :voided_at

      t.timestamps

      t.check_constraint "sequential_id > 0",
        name: "order_forms_constraint_sequential_id_positive"
      t.index [:organization_id, :sequential_id],
        unique: true,
        name: "index_unique_order_forms_on_organization_sequential_id"
      t.index [:organization_id, :number],
        unique: true,
        name: "index_unique_order_forms_on_organization_number"
      t.index [:organization_id, :status]
      t.index [:organization_id, :created_at]
      t.index [:organization_id, :expires_at]
    end
  end
end
