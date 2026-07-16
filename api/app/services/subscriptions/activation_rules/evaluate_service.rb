# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class EvaluateService < BaseService
      Result = BaseResult[:subscription, :rules]

      def initialize(subscription:)
        @subscription = subscription
        super
      end

      def call
        result.rules = []

        subscription.activation_rules.each do |rule|
          rule.evaluate!
          result.rules << rule
        end

        result.subscription = subscription
        result
      end

      private

      attr_reader :subscription
    end
  end
end
