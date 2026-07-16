# frozen_string_literal: true

module PaymentMethods
  class ValidateService < BaseValidator
    def valid?
      return true unless args[:payment_method]

      valid_payment_method_attributes?

      if errors?
        result.validation_failure!(errors:)
        return false
      end

      true
    end

    private

    def valid_payment_method_attributes?
      return true if args[:payment_method].blank?
      return true if args[:payment_method][:payment_method_type].blank? && args[:payment_method][:payment_method_id].blank?
      return true if args[:payment_method][:payment_method_id].nil? && args[:payment_method][:payment_method_type].to_s == "provider"
      return true if result.payment_method && args[:payment_method][:payment_method_type].to_s == "provider"
      return true if result.payment_method.nil? && args[:payment_method][:payment_method_type].to_s == "manual"

      add_error(field: :payment_method, error_code: "invalid_payment_method")
    end
  end
end
