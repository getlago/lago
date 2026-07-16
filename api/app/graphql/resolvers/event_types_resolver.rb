# frozen_string_literal: true

module Resolvers
  class EventTypesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser

    REQUIRED_PERMISSION = "developers:manage"

    description "Query Event Types for Webhook Endpoints"

    type [Types::WebhookEndpoints::EventType], null: false

    def resolve
      WebhookEndpoint::WEBHOOK_EVENT_TYPE_CONFIG.map do |key, event_type|
        {
          key: event_type[:name],
          name: event_type[:name],
          description: event_type[:description],
          category: event_type[:category],
          deprecated: event_type[:deprecated]
        }
      end
    end
  end
end
