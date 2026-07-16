# frozen_string_literal: true

module Types
  module WebhookEndpoints
    class EventType < Types::BaseObject
      graphql_name "WebhookEventType"

      field :category, Types::WebhookEndpoints::EventCategoryEnum, null: false
      field :deprecated, Boolean, null: false
      field :description, String, null: false
      field :key, Types::WebhookEndpoints::EventTypeEnum, null: false
      field :name, String, null: false
    end
  end
end
