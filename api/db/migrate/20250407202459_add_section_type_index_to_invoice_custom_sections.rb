# frozen_string_literal: true

class AddSectionTypeIndexToInvoiceCustomSections < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_index :invoice_custom_sections, :section_type, algorithm: :concurrently
  end

  def down
    remove_index :invoice_custom_sections, column: :section_type
  end
end
