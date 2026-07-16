# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class ResolveSubscriptionStatusService < BaseService
      Result = BaseResult[:subscription]

      def initialize(subscription:)
        @subscription = subscription
        super
      end

      def call
        return result.tap { result.subscription = subscription } unless subscription.incomplete?

        if all_rules_satisfied?
          Subscriptions::ActivateService.call!(subscription:)
        elsif any_rule_failed?
          subscription.mark_as_canceled!
          SendWebhookJob.perform_after_commit("subscription.canceled", subscription)
          Utils::ActivityLog.produce_after_commit(subscription, "subscription.canceled")
        end

        result.subscription = subscription
        result
      end

      private

      attr_reader :subscription

      def all_rules_satisfied?
        subscription.activation_rules.where.not(status: Subscription::ActivationRule::FULFILLED_STATUSES).none?
      end

      def any_rule_failed?
        subscription.activation_rules.rejected.exists?
      end
    end
  end
end
