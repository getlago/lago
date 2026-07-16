# frozen_string_literal: true

module Mutations
  module CreditNotes
    class DownloadXml < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "credit_notes:view"

      graphql_name "DownloadXmlCreditNote"
      description "Download a Credit Note XML"

      argument :id, ID, required: true

      type Types::CreditNotes::Object

      def resolve(**args)
        result = ::CreditNotes::GenerateXmlService.call(
          credit_note: current_organization.credit_notes.find_by(id: args[:id])
        )

        result.success? ? result.credit_note : result_error(result)
      end
    end
  end
end
