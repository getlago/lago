# frozen_string_literal: true

module Types
  module Integrations
    class SyncCreditNoteInput < Types::BaseInputObject
      graphql_name "SyncIntegrationCreditNoteInput"

      argument :credit_note_id, ID, required: true
    end
  end
end
