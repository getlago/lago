# frozen_string_literal: true

module Mutations
  module CustomerPortal
    class DownloadInvoice < BaseMutation
      include AuthenticableCustomerPortalUser

      graphql_name "DownloadCustomerPortalInvoice"
      description "Download customer portal invoice PDF"

      argument :id, ID, required: true

      type Types::Invoices::Object

      def resolve(id:)
        invoice = context[:customer_portal_user].invoices.visible.find_by(id:)
        result = ::Invoices::GeneratePdfService.call(invoice:)
        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
