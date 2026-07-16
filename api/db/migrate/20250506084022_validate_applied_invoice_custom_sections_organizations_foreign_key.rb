# frozen_string_literal: true

class ValidateAppliedInvoiceCustomSectionsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :applied_invoice_custom_sections, :organizations
  end
end
