# frozen_string_literal: true

module Mutations
  module Invoices
    class RetryAllPayments < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      graphql_name "RetryAllInvoicePayments"
      description "Retry all invoice payments"

      type Types::Invoices::Object.collection_type

      def resolve
        result = ::Invoices::Payments::RetryBatchService.new(organization_id: current_organization.id).call_async

        result.success? ? Kaminari.paginate_array(result.invoices) : result_error(result)
      end
    end
  end
end
