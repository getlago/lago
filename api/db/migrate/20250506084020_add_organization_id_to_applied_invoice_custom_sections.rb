# frozen_string_literal: true

class AddOrganizationIdToAppliedInvoiceCustomSections < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :applied_invoice_custom_sections, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
