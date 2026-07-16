# frozen_string_literal: true

module Mutations
  module Invoices
    class DownloadXml < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:view"

      graphql_name "DownloadXmlInvoice"
      description "Download an Invoice XML"

      argument :id, ID, required: true

      type Types::Invoices::Object

      def resolve(id:)
        invoice = current_organization.invoices.visible.find_by(id:)
        result = ::Invoices::GenerateXmlService.call(invoice:)
        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
