# frozen_string_literal: true

class OrganizationIdCheckConstaintOnInvoiceMetadata < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :invoice_metadata,
      "organization_id IS NOT NULL",
      name: "invoice_metadata_organization_id_not_null",
      validate: false
  end
end
