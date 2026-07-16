# frozen_string_literal: true

module Mutations
  module Integrations
    class SyncCreditNote < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "SyncIntegrationCreditNote"
      description "Sync integration credit note"

      input_object_class Types::Integrations::SyncCreditNoteInput

      field :credit_note_id, ID, null: true

      def resolve(**args)
        credit_note = current_organization.credit_notes.find_by(id: args[:credit_note_id])

        result = ::Integrations::Aggregator::CreditNotes::CreateService.call_async(credit_note:)
        result.success? ? result.credit_note_id : result_error(result)
        result
      end
    end
  end
end
