# frozen_string_literal: true

module Types
  module Webhooks
    class StatusEnum < Types::BaseEnum
      graphql_name "WebhookStatusEnum"

      Webhook::STATUS.each do |type|
        value type
      end
    end
  end
end
