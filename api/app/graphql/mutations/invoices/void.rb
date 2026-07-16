# frozen_string_literal: true

module Mutations
  module Invoices
    class Void < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:void"

      graphql_name "VoidInvoice"
      description "Void an invoice"

      input_object_class Types::Invoices::VoidInvoiceInput

      type Types::Invoices::Object

      def resolve(**args)
        invoice = current_organization.invoices.visible.find_by(id: args[:id])
        params = args.slice(:generate_credit_note, :refund_amount, :credit_amount)

        result = ::Invoices::VoidService.call(
          invoice: invoice,
          params: params
        )

        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
