# frozen_string_literal: true

module Integrations
  module Aggregator
    class RequestLimitError < StandardError
      def initialize(http_error)
        @http_error = http_error
        super(http_error.message)
      end

      attr_reader :http_error
    end
  end
end
