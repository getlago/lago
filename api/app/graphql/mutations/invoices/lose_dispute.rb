# frozen_string_literal: true

module Mutations
  module Invoices
    class LoseDispute < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      graphql_name "LoseInvoiceDispute"
      description "Mark payment dispute as lost"

      argument :id, ID, required: true

      type Types::Invoices::Object

      def resolve(**args)
        result = ::Invoices::LoseDisputeService.call(
          invoice: current_organization.invoices.visible.find_by(id: args[:id]),
          payment_dispute_lost_at: DateTime.current
        )
        result.success? ? result.invoice : result_error(result)
      end
    end
  end
end
