# frozen_string_literal: true

module Mutations
  module Invoices
    class GeneratePaymentUrl < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      description "Generates a payment URL for an invoice"

      argument :invoice_id, ID, required: true

      field :payment_url, String, null: true

      def resolve(invoice_id:)
        invoice = current_organization.invoices.visible.includes(:customer).find_by(id: invoice_id)
        return not_found_error(resource: "invoice") unless invoice

        result = ::Invoices::Payments::GeneratePaymentUrlService.call(invoice:)

        result.success? ? result : result_error(result)
      end
    end
  end
end
