# frozen_string_literal: true

module Types
  module WebhookEndpoints
    class UpdateInput < BaseInputObject
      graphql_name "WebhookEndpointUpdateInput"

      argument :event_types, [Types::WebhookEndpoints::EventTypeEnum], required: false
      argument :id, ID, required: true
      argument :name, String, required: false
      argument :signature_algo, Types::WebhookEndpoints::SignatureAlgoEnum, required: false
      argument :webhook_url, String, required: true
    end
  end
end
