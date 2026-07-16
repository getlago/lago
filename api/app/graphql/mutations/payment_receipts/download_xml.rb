# frozen_string_literal: true

module Mutations
  module PaymentReceipts
    class DownloadXml < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:view"

      graphql_name "DownloadXMLPaymentReceipt"
      description "Download an PaymentReceipt XML"

      argument :id, ID, required: true

      type Types::PaymentReceipts::Object

      def resolve(id:)
        payment_receipt = current_organization.payment_receipts.find_by(id:)
        result = ::PaymentReceipts::GenerateXmlService.call(payment_receipt:)
        result.success? ? result.payment_receipt : result_error(result)
      end
    end
  end
end
