# frozen_string_literal: true

module Types
  module Webhooks
    class Object < Types::BaseObject
      graphql_name "Webhook"

      field :id, ID, null: false
      field :webhook_endpoint, Types::WebhookEndpoints::Object

      field :endpoint, String, null: false
      field :object_type, String, null: false
      field :retries, Integer, null: false
      field :status, Types::Webhooks::StatusEnum, null: false
      field :webhook_type, String, null: false

      field :http_status, Integer, null: true
      field :payload, String, null: true
      field :response, String, null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :last_retried_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      def payload
        object.payload&.to_json
      end
    end
  end
end
