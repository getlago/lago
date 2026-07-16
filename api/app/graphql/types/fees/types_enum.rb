# frozen_string_literal: true

module Types
  module Fees
    class TypesEnum < Types::BaseEnum
      graphql_name "FeeTypesEnum"

      Fee::FEE_TYPES.each do |type|
        value type
      end
    end
  end
end
