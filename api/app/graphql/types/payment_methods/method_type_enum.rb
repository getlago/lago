# frozen_string_literal: true

module Types
  module PaymentMethods
    class MethodTypeEnum < Types::BaseEnum
      graphql_name "PaymentMethodTypeEnum"

      PaymentMethod::PAYMENT_METHOD_TYPES.keys.each do |type|
        value type
      end
    end
  end
end
