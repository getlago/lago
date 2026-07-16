# frozen_string_literal: true

module Types
  module Customers
    class CustomerTypeEnum < Types::BaseEnum
      Customer::CUSTOMER_TYPES.keys.each do |type|
        value type
      end
    end
  end
end
