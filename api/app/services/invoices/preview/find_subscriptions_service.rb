# frozen_string_literal: true

module Invoices
  module Preview
    class FindSubscriptionsService < BaseService
      Result = BaseResult[:subscriptions]

      def initialize(subscriptions:)
        @subscriptions = subscriptions
        super
      end

      def call
        return result.not_found_failure!(resource: "subscription") if subscriptions.empty?

        result.subscriptions = subscriptions.flat_map do |subscription|
          if subscription.downgraded?
            sub = adjusted_subscription(subscription)

            [
              sub,
              (sub.next_subscription if sub.next_subscription.plan.pay_in_advance?)
            ].compact
          elsif subscriptions.size == 1 && subscription.pending?
            # We need to activate subscription at future billing time. We are also making
            # duplicate of subscription in order to re-use calculation for non-existing
            # future subscription, since we already have this flow covered and invoice
            # calculation is the same
            duplicate = subscription.dup

            duplicate.assign_attributes(
              status: :active,
              started_at: subscription.subscription_at,
              created_at: subscription.subscription_at
            )

            duplicate
          else
            subscription
          end
        end

        result
      end

      private

      attr_reader :subscriptions

      def adjusted_subscription(subscription)
        date_service = Subscriptions::DatesService.new_instance(subscription, Time.current, current_usage: true)

        subscription.terminated_at = date_service.end_of_period + 1.day
        subscription.status = :terminated

        subscription.next_subscription.assign_attributes(
          status: :active,
          started_at: date_service.next_period_started_at
        )

        subscription
      end
    end
  end
end
