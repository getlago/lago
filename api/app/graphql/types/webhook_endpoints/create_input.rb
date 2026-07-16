# frozen_string_literal: true

module Types
  module WebhookEndpoints
    class CreateInput < BaseInputObject
      graphql_name "WebhookEndpointCreateInput"

      argument :event_types, [Types::WebhookEndpoints::EventTypeEnum], required: false
      argument :name, String, required: false
      argument :signature_algo, Types::WebhookEndpoints::SignatureAlgoEnum, required: false
      argument :webhook_url, String, required: true
    end
  end
end
