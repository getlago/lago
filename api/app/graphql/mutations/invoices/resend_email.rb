# frozen_string_literal: true

module Mutations
  module Invoices
    class ResendEmail < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:send"

      graphql_name "ResendInvoiceEmail"
      description "Resend invoice email with optional custom recipients"

      input_object_class Types::Emails::ResendEmailInput

      type Types::Invoices::Object

      def resolve(**args)
        invoice = current_organization.invoices.visible.find_by(id: args[:id])

        result = ::Emails::ResendService.call(
          resource: invoice,
          to: args[:to],
          cc: args[:cc],
          bcc: args[:bcc]
        )

        result.success? ? invoice : result_error(result)
      end
    end
  end
end
