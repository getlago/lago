# frozen_string_literal: true

module Mutations
  module Invoices
    class FinalizeAll < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      graphql_name "FinalizeAllInvoices"
      description "Finalize all draft invoices"

      type Types::Invoices::Object.collection_type

      def resolve
        result = ::Invoices::FinalizeBatchService.new(organization: current_organization).call_async

        result.success? ? Kaminari.paginate_array(result.invoices) : result_error(result)
      end
    end
  end
end
