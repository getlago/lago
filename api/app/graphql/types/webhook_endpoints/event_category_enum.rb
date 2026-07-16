# frozen_string_literal: true

module Types
  module WebhookEndpoints
    class EventCategoryEnum < Types::BaseEnum
      WebhookEndpoint::WEBHOOK_EVENT_TYPE_CONFIG.values
        .map { |e| e[:category].to_s }
        .uniq
        .each do |category|
          graphql_key = category.parameterize(separator: "_").upcase

          value graphql_key, value: category
      end
    end
  end
end
