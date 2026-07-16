# frozen_string_literal: true

module Types
  module WebhookEndpoints
    class Object < Types::BaseObject
      graphql_name "WebhookEndpoint"

      field :event_types, [Types::WebhookEndpoints::EventTypeEnum], null: true
      field :id, ID, null: false
      field :name, String, null: true
      field :organization, Types::Organizations::OrganizationType
      field :signature_algo, Types::WebhookEndpoints::SignatureAlgoEnum
      field :webhook_url, String, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
