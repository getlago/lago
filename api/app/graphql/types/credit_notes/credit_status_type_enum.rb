# frozen_string_literal: true

module Types
  module CreditNotes
    class CreditStatusTypeEnum < Types::BaseEnum
      graphql_name "CreditNoteCreditStatusEnum"

      CreditNote::CREDIT_STATUS.each do |type|
        value type
      end
    end
  end
end
