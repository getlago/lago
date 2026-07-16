# frozen_string_literal: true

module Mutations
  module Invoices
    class RetryAll < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      graphql_name "RetryAllInvoices"
      description "Retry all failed invoices"

      type Types::Invoices::Object.collection_type

      def resolve
        result = ::Invoices::RetryBatchService.new(organization: current_organization).call_async

        result.success? ? Kaminari.paginate_array(result.invoices) : result_error(result)
      end
    end
  end
end
