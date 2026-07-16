# frozen_string_literal: true

class NotNullOrganizationIdOnAppliedInvoiceCustomSections < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :applied_invoice_custom_sections, name: "applied_invoice_custom_sections_organization_id_not_null"
    change_column_null :applied_invoice_custom_sections, :organization_id, false
    remove_check_constraint :applied_invoice_custom_sections, name: "applied_invoice_custom_sections_organization_id_not_null"
  end

  def down
    add_check_constraint :applied_invoice_custom_sections, "organization_id IS NOT NULL", name: "applied_invoice_custom_sections_organization_id_not_null", validate: false
    change_column_null :applied_invoice_custom_sections, :organization_id, true
  end
end
