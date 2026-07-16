# frozen_string_literal: true

module Types
  module Quotes
    class OrderTypeEnum < Types::BaseEnum
      Quote::ORDER_TYPES.each_key do |type|
        value type
      end
    end
  end
end
