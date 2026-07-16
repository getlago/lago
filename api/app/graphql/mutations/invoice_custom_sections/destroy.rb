# frozen_string_literal: true

module Mutations
  module InvoiceCustomSections
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoice_custom_sections:delete"

      graphql_name "DestroyInvoiceCustomSection"
      description "Deletes an invoice_custom_section"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        invoice_custom_section = current_organization.invoice_custom_sections.find_by(id:)
        result = ::InvoiceCustomSections::DestroyService.call(invoice_custom_section:)

        result.success? ? result.invoice_custom_section : result_error(result)
      end
    end
  end
end
