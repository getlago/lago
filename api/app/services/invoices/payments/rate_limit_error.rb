# frozen_string_literal: true

module Invoices
  module Payments
    class RateLimitError < StandardError
      def initialize(initial_error)
        @initial_error = initial_error

        super(initial_error.message)
      end

      attr_reader :initial_error
    end
  end
end
