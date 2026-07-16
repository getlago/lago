# frozen_string_literal: true

class AddSectionTypeToInvoiceCustomSections < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    create_enum :invoice_custom_section_type, %w[manual system_generated]

    safety_assured do
      change_table :invoice_custom_sections, bulk: true do |t|
        t.column :section_type, :enum, enum_type: "invoice_custom_section_type", null: true
      end
    end

    # Backfill all existing rows as manual
    InvoiceCustomSection.unscoped.in_batches(of: 10_000).update_all(section_type: "manual") # rubocop:disable Rails/SkipsModelValidations

    safety_assured do
      execute <<~SQL
        ALTER TABLE invoice_custom_sections ALTER COLUMN section_type SET DEFAULT 'manual';
      SQL
      execute <<~SQL
        ALTER TABLE invoice_custom_sections ALTER COLUMN section_type SET NOT NULL;
      SQL
    end
  end

  def down
    change_table :invoice_custom_sections, bulk: true do |t|
      t.remove :section_type
    end

    drop_enum :invoice_custom_section_type
  end
end
