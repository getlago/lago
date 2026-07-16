# frozen_string_literal: true

module Mutations
  module PaymentReceipts
    class ResendEmail < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "payment_receipts:send"

      graphql_name "ResendPaymentReceiptEmail"
      description "Resend payment receipt email with optional custom recipients"

      input_object_class Types::Emails::ResendEmailInput

      type Types::PaymentReceipts::Object

      def resolve(**args)
        payment_receipt = PaymentReceipt.find_by(id: args[:id], organization_id: current_organization.id)

        result = ::Emails::ResendService.call(
          resource: payment_receipt,
          to: args[:to],
          cc: args[:cc],
          bcc: args[:bcc]
        )

        result.success? ? payment_receipt : result_error(result)
      end
    end
  end
end
