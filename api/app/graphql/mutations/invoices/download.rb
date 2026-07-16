# frozen_string_literal: true

module Mutations
  module Invoices
    class Download < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:view"

      graphql_name "DownloadInvoice"
      description "Download an Invoice PDF"

      argument :id, ID, required: true

      type Types::Invoices::Object

      def resolve(id:)
        invoice = current_organization.invoices.visible.find_by(id:)
        result = ::Invoices::GeneratePdfService.call(invoice:)
        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
