# frozen_string_literal: true

module Webhooks
  module Subscriptions
    class TerminatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::SubscriptionSerializer.new(
          object,
          root_name: "subscription",
          includes: %i[plan customer]
        )
      end

      def webhook_type
        "subscription.terminated"
      end

      def object_type
        "subscription"
      end
    end
  end
end
