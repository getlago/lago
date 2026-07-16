# frozen_string_literal: true

class CreateCustomerAppliedInvoiceCustomSectionRecords < ActiveRecord::Migration[8.0]
  class InvoiceCustomSectionSelection < ApplicationRecord; end

  def up
    Customer::AppliedInvoiceCustomSection.insert_all( # rubocop:disable Rails/SkipsModelValidations
      InvoiceCustomSectionSelection
        .joins("LEFT JOIN customers ON customers.id = invoice_custom_section_selections.customer_id")
        .where("invoice_custom_section_selections.customer_id IS NOT NULL AND customers.id IS NOT NULL AND customers.deleted_at IS NULL")
        .select(
          "invoice_custom_section_selections.id",
          "invoice_custom_section_selections.customer_id",
          "invoice_custom_section_selections.invoice_custom_section_id",
          "invoice_custom_section_selections.created_at",
          "invoice_custom_section_selections.updated_at",
          "customers.organization_id",
          "customers.billing_entity_id"
        )
        .map do |selection|
          {
            id: selection.id,
            organization_id: selection.organization_id,
            billing_entity_id: selection.billing_entity_id,
            customer_id: selection.customer_id,
            invoice_custom_section_id: selection.invoice_custom_section_id,
            created_at: selection.created_at,
            updated_at: selection.updated_at
          }
        end
    )
  end

  def down
    Customer::AppliedInvoiceCustomSection.delete_all
  end
end
