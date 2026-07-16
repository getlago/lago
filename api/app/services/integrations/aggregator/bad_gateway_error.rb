# frozen_string_literal: true

module Integrations
  module Aggregator
    class BadGatewayError < LagoHttpClient::HttpError
      def initialize(body, uri)
        super(502, body, uri)
      end
    end
  end
end
