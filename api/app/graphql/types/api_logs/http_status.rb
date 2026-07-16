# frozen_string_literal: true

module Types
  module ApiLogs
    class HttpStatus < Types::BaseScalar
      description "Api Logs HTTP status"

      def self.coerce_input(input_value, _context)
        Integer(input_value)
      rescue ArgumentError, TypeError
        input_value.to_s
      end

      def self.coerce_result(result_value, _context)
        result_value
      end
    end
  end
end
