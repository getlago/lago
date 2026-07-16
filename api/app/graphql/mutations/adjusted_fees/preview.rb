# frozen_string_literal: true

module Mutations
  module AdjustedFees
    class Preview < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "invoices:update"

      graphql_name "PreviewAdjustedFee"
      description "Preview Adjusted Fee"

      input_object_class Types::AdjustedFees::CreateInput

      type Types::Fees::Object

      def resolve(**args)
        invoice = current_organization.invoices.find_by(id: args[:invoice_id])

        result = ::AdjustedFees::EstimateService.call(invoice:, params: args)
        result.success? ? result.fee : result_error(result)
      end
    end
  end
end
