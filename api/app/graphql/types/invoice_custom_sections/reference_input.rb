# frozen_string_literal: true

module Types
  module InvoiceCustomSections
    class ReferenceInput < Types::BaseInputObject
      graphql_name "InvoiceCustomSectionsReferenceInput"

      argument :invoice_custom_section_ids, [ID], required: false
      argument :skip_invoice_custom_sections, Boolean, required: false
    end
  end
end
