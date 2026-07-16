# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class ValidateService < BaseValidator
      def valid?
        valid_activation_rules_format?
        valid_subscription_status?
        valid_rules? unless errors[:activation_rules]&.include?("invalid_format")

        if errors?
          result.validation_failure!(errors:)
          return false
        end

        true
      end

      private

      def valid_activation_rules_format?
        return true if args[:activation_rules].is_a?(Array)

        add_error(field: :activation_rules, error_code: "invalid_format")
      end

      def valid_subscription_status?
        return true unless args[:subscription_type] == "update"
        return true if args[:subscription].pending?

        add_error(field: :activation_rules, error_code: "subscription_not_pending")
      end

      def valid_rules?
        return true if args[:activation_rules].blank?

        args[:activation_rules].each do |rule|
          next unless valid_rule_type?(rule)

          validate_specific_rule(rule)
        end

        duplicated_rule_types?
      end

      def duplicated_rule_types?
        types = args[:activation_rules].map { |rule| rule[:type].to_s }
        return true if types.uniq.size == types.size

        add_error(field: :activation_rules, error_code: "duplicated_type")
      end

      def valid_rule_type?(rule)
        return true if Subscription::ActivationRule::STI_MAPPING.key?(rule[:type].to_s)

        add_error(field: :activation_rules, error_code: "invalid_type")
      end

      def validate_specific_rule(rule)
        validator = case rule[:type].to_s
        when "payment"
          Payment::ValidateService.new(
            result,
            rule:,
            payment_method: args[:payment_method],
            subscription: args[:subscription],
            customer: args[:customer]
          )
        end

        return true if validator.nil?
        return true if validator.valid?

        validator.errors.each do |field, codes|
          codes.each { |code| add_error(field:, error_code: code) }
        end

        false
      end
    end
  end
end
