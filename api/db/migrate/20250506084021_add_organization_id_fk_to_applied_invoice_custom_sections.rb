# frozen_string_literal: true

class AddOrganizationIdFkToAppliedInvoiceCustomSections < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :applied_invoice_custom_sections, :organizations, validate: false
  end
end
