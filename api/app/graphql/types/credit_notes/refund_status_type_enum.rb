# frozen_string_literal: true

module Types
  module CreditNotes
    class RefundStatusTypeEnum < Types::BaseEnum
      graphql_name "CreditNoteRefundStatusEnum"

      CreditNote::REFUND_STATUS.each do |type|
        value type
      end
    end
  end
end
