# frozen_string_literal: true

module OrderForms
  module ExecutionSettingsValidation
    extend ActiveSupport::Concern

    private

    def validate_execution_mode(execution_mode:, execute_at:)
      return if execution_mode.blank? && execute_at.blank?

      if execution_mode.blank?
        return result.single_validation_failure!(field: :execution_mode, error_code: "value_is_mandatory")
      end

      return if Order::EXECUTION_MODES.value?(execution_mode.to_s)

      result.single_validation_failure!(field: :execution_mode, error_code: "value_is_invalid")
    end

    def validate_execute_at(execute_at:)
      return if execute_at.blank?
      return if Utils::Datetime.future_date?(execute_at)

      result.single_validation_failure!(field: :execute_at, error_code: "invalid_date")
    end
  end
end
