# frozen_string_literal: true

module Types
  module Payments
    class PayablePaymentStatusEnum < Types::BaseEnum
      Payment::PAYABLE_PAYMENT_STATUS.each do |type|
        value type
      end
    end
  end
end
