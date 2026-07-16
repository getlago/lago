# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    module Payment
      class EvaluateService < BaseService
        Result = BaseResult[:rule]

        def initialize(rule:, status: nil)
          @rule = rule
          @status = status
          super
        end

        def call
          case rule.status.to_sym
          when :inactive
            evaluate_inactive_rule
          when :pending
            transition_pending_rule
          end

          result.rule = rule
          result
        end

        private

        attr_reader :rule, :status

        def evaluate_inactive_rule
          if rule.applicable?
            rule.expires_at = compute_expires_at
            rule.pending!
          else
            rule.not_applicable!
          end
        end

        def transition_pending_rule
          raise ArgumentError, "status required to transition a pending rule" if status.blank?

          rule.public_send(:"#{status}!")
        end

        def compute_expires_at
          return nil if rule.timeout_hours.zero?

          Time.current + rule.timeout_hours.hours
        end
      end
    end
  end
end
