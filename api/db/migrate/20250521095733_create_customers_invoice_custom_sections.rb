# frozen_string_literal: true

class CreateCustomersInvoiceCustomSections < ActiveRecord::Migration[8.0]
  def change
    create_table :customers_invoice_custom_sections, id: :uuid do |t|
      t.belongs_to :organization, null: false, foreign_key: true, type: :uuid
      t.belongs_to :billing_entity, null: false, foreign_key: true, type: :uuid
      t.belongs_to :customer, null: false, foreign_key: true, type: :uuid
      t.belongs_to :invoice_custom_section, null: false, foreign_key: true, type: :uuid

      t.timestamps

      t.index %i[billing_entity_id customer_id invoice_custom_section_id],
        unique: true
    end
  end
end
