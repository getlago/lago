# frozen_string_literal: true

module Mutations
  module Invoices
    class Retry < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      graphql_name "RetryInvoice"
      description "Retry failed invoice"

      argument :id, ID, required: true

      type Types::Invoices::Object

      def resolve(**args)
        invoice = current_organization.invoices.visible.find_by(id: args[:id])
        result = ::Invoices::RetryService.new(invoice:).call

        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
