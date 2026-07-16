# frozen_string_literal: true

module Types
  module ChargeFilters
    class Values < Types::BaseScalar
      graphql_name "ChargeFilterValues"

      def self.coerce_input(input_value, _context)
        input_value.to_h.each_with_object({}) do |(key, values), result|
          result[key.to_s] = values&.map(&:to_s) || []
        end
      rescue
        raise GraphQL::CoercionError, "#{input_value.inspect} is not a valid hash object"
      end

      def self.coerce_result(ruby_value, _context)
        ruby_value.to_h
      end
    end
  end
end
