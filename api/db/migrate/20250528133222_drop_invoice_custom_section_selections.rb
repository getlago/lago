# frozen_string_literal: true

class DropInvoiceCustomSectionSelections < ActiveRecord::Migration[8.0]
  def up
    drop_table :invoice_custom_section_selections
  end
end
