# frozen_string_literal: true

module Types
  module Subscriptions
    class LifetimeUsageObject < Types::BaseObject
      graphql_name "SubscriptionLifetimeUsage"

      field :total_usage_amount_cents, GraphQL::Types::BigInt, method: :total_amount_cents, null: false
      field :total_usage_from_datetime, GraphQL::Types::ISO8601DateTime, null: false
      field :total_usage_to_datetime, GraphQL::Types::ISO8601DateTime, null: false

      field :last_threshold_amount_cents, GraphQL::Types::BigInt, null: true
      field :next_threshold_amount_cents, GraphQL::Types::BigInt, null: true
      field :next_threshold_ratio, GraphQL::Types::Float, null: true

      def total_usage_from_datetime
        object.subscription.subscription_at
      end

      def total_usage_to_datetime
        Time.current
      end

      private

      delegate :last_threshold_amount_cents,
        :next_threshold_amount_cents,
        :next_threshold_ratio,
        to: :last_and_next_thresholds

      def last_and_next_thresholds
        @last_and_next_thresholds ||= LifetimeUsages::FindLastAndNextThresholdsService.call(lifetime_usage: object)
      end
    end
  end
end
