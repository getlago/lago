# frozen_string_literal: true

class CreateBillingEntitiesInvoiceCustomSections < ActiveRecord::Migration[8.0]
  def change
    create_table :billing_entities_invoice_custom_sections, id: :uuid do |t|
      t.belongs_to :organization, null: false, foreign_key: true, type: :uuid
      t.belongs_to :billing_entity, null: false, foreign_key: true, type: :uuid
      t.belongs_to :invoice_custom_section, null: false, foreign_key: true, type: :uuid

      t.timestamps

      t.index [:billing_entity_id, :invoice_custom_section_id], unique: true
    end
  end
end
