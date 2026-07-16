# frozen_string_literal: true

module Mutations
  module AdjustedFees
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      graphql_name "DestroyAdjustedFee"
      description "Deletes an adjusted fee"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        fee = current_organization.fees
          .where(invoice_id: current_organization.invoices.draft.select(:id))
          .find_by(id:)

        result = ::AdjustedFees::DestroyService.call(fee:)

        result.success? ? result.fee : result_error(result)
      end
    end
  end
end
