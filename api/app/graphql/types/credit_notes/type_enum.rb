# frozen_string_literal: true

module Types
  module CreditNotes
    class TypeEnum < Types::BaseEnum
      graphql_name "CreditNoteTypeEnum"

      CreditNote::TYPES.each do |type|
        value type
      end
    end
  end
end
