# frozen_string_literal: true

module Resolvers
  module CreditNotes
    class EstimateResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      description "Fetch amounts for credit note creation"

      argument :invoice_id, ID, required: true
      argument :items, [Types::CreditNoteItems::Input], required: true

      type Types::CreditNotes::Estimate, null: false

      def resolve(invoice_id:, items:)
        result = ::CreditNotes::EstimateService.call(
          invoice: current_organization.invoices.visible.find_by(id: invoice_id),
          items:
        )

        result.success? ? result.credit_note : result_error(result)
      end
    end
  end
end
