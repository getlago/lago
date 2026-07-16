# frozen_string_literal: true

module Resolvers
  class CreditNoteResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "credit_notes:view"

    description "Query a single credit note"

    argument :id, ID, required: true, description: "Uniq ID of the credit note"

    type Types::CreditNotes::Object, null: true

    def resolve(id: nil)
      current_organization.credit_notes.finalized.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "credit_note")
    end
  end
end
