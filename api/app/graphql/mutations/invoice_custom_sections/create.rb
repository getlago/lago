# frozen_string_literal: true

module Mutations
  module InvoiceCustomSections
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoice_custom_sections:create"

      graphql_name "CreateInvoiceCustomSection"
      description "Creates a new InvoiceCustomSection"

      input_object_class Types::InvoiceCustomSections::CreateInput

      type Types::InvoiceCustomSections::Object

      def resolve(**args)
        result = ::InvoiceCustomSections::CreateService.call(
          organization: current_organization, create_params: args.to_h
        )

        result.success? ? result.invoice_custom_section : result_error(result)
      end
    end
  end
end
