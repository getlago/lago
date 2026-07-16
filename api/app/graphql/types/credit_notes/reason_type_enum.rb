# frozen_string_literal: true

module Types
  module CreditNotes
    class ReasonTypeEnum < Types::BaseEnum
      graphql_name "CreditNoteReasonEnum"

      CreditNote::REASON.each do |reason|
        value reason
      end
    end
  end
end
