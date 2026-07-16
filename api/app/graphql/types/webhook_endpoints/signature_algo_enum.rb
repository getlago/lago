# frozen_string_literal: true

module Types
  module WebhookEndpoints
    class SignatureAlgoEnum < Types::BaseEnum
      graphql_name "WebhookEndpointSignatureAlgoEnum"

      WebhookEndpoint::SIGNATURE_ALGOS.each do |type|
        value type
      end
    end
  end
end
