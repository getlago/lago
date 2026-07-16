# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class ApplyService < BaseService
      Result = BaseResult[:activation_rules]

      def initialize(subscription:, activation_rules:)
        @subscription = subscription
        @activation_rules = activation_rules

        super
      end

      def call
        return result if activation_rules.nil?
        return result.single_validation_failure!(field: :activation_rules, error_code: "subscription_not_pending") unless subscription.pending?

        subscription.activation_rules.destroy_all

        activation_rules.each do |rule_params|
          subscription.activation_rules.create!(
            organization_id: subscription.organization_id,
            status: :inactive,
            **rule_params.to_h.with_indifferent_access.slice(:type, :timeout_hours)
          )
        end

        result.activation_rules = subscription.activation_rules.reload
        result
      end

      private

      attr_reader :subscription, :activation_rules
    end
  end
end
