# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    module Payment
      class ValidateService < BaseValidator
        def valid?
          valid_timeout_hours?
          valid_payment_method?

          if errors?
            result.validation_failure!(errors:)
            return false
          end

          true
        end

        private

        def valid_timeout_hours?
          return true unless args[:rule].key?(:timeout_hours)
          return true if args[:rule][:timeout_hours].is_a?(Integer) && args[:rule][:timeout_hours] >= 0

          add_error(field: :timeout_hours, error_code: "value_must_be_positive_or_zero")
        end

        def valid_payment_method?
          if effective_payment_method_type.present?
            return true if effective_payment_method_type_provider? && resolved_payment_method.present?
          elsif customer_payment_provider? && resolved_payment_method.present?
            return true
          end

          add_error(field: :customer, error_code: failure_error_code)
        end

        def effective_payment_method_type_provider?
          effective_payment_method_type == PaymentMethod::PAYMENT_METHOD_TYPES[:provider]
        end

        def effective_payment_method_type
          return args[:payment_method][:payment_method_type] if args[:payment_method]&.key?(:payment_method_type)

          args[:subscription]&.payment_method_type
        end

        def effective_payment_method_id
          return args[:payment_method][:payment_method_id] if args[:payment_method]&.key?(:payment_method_id)

          args[:subscription]&.payment_method_id
        end

        def resolved_payment_method
          return args[:customer].payment_methods.find_by(id: effective_payment_method_id) if effective_payment_method_id.present?

          args[:customer].default_payment_method
        end

        def failure_error_code
          if effective_payment_method_type.present?
            return "manual_payment_method_invalid_for_payment_activation_rules" unless effective_payment_method_type_provider?
          elsif !customer_payment_provider?
            return "no_linked_payment_provider"
          end

          return "payment_method_not_found" if effective_payment_method_id.present?

          "no_default_payment_method"
        end

        def customer_payment_provider?
          args[:customer].payment_provider.present?
        end
      end
    end
  end
end
