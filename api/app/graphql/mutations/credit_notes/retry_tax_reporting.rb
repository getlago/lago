# frozen_string_literal: true

module Mutations
  module CreditNotes
    class RetryTaxReporting < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "credit_notes:update"

      description "Retry tax reporting"

      argument :id, ID, required: true

      type Types::CreditNotes::Object

      def resolve(**args)
        credit_note = current_organization.credit_notes.find_by(id: args[:id])
        result = ::CreditNotes::ProviderTaxes::ReportService.call(credit_note:)

        result.success? ? result.credit_note : result_error(result)
      end
    end
  end
end
