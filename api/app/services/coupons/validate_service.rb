# frozen_string_literal: true

module Coupons
  class ValidateService < BaseValidator
    def valid?
      valid_expiration_at?

      if errors?
        result.validation_failure!(errors:)
        return false
      end

      true
    end

    private

    def valid_expiration_at?
      return true if Validators::ExpirationDateValidator.valid?(args[:expiration_at])

      add_error(field: :expiration_at, error_code: "invalid_date")
      false
    end
  end
end
