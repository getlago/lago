# frozen_string_literal: true

class NotNullOrganizationIdOnInvoiceMetadata < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :invoice_metadata, name: "invoice_metadata_organization_id_not_null"
    change_column_null :invoice_metadata, :organization_id, false
    remove_check_constraint :invoice_metadata, name: "invoice_metadata_organization_id_not_null"
  end

  def down
    add_check_constraint :invoice_metadata, "organization_id IS NOT NULL", name: "invoice_metadata_organization_id_not_null", validate: false
    change_column_null :invoice_metadata, :organization_id, true
  end
end
