# frozen_string_literal: true

class OrganizationIdCheckConstaintOnAppliedInvoiceCustomSections < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :applied_invoice_custom_sections,
      "organization_id IS NOT NULL",
      name: "applied_invoice_custom_sections_organization_id_not_null",
      validate: false
  end
end
