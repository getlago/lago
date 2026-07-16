# frozen_string_literal: true

module Types
  module Payments
    class PaymentTypeEnum < Types::BaseEnum
      Payment::PAYMENT_TYPES.keys.each do |type|
        value type
      end
    end
  end
end
