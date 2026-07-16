# frozen_string_literal: true

module Charges
  module Validators
    class PercentageService < Charges::Validators::BaseService
      def valid?
        validate_billable_metric
        validate_rate
        validate_fixed_amount
        validate_free_units_per_events
        validate_free_units_per_total_aggregation
        validate_per_transaction_min_max

        super
      end

      private

      def rate
        properties["rate"]
      end

      def validate_billable_metric
        return unless charge.billable_metric.latest_agg?

        add_error(field: :billable_metric, error_code: "invalid_value")
      end

      def validate_rate
        return if ::Validators::DecimalAmountService.new(rate).valid_amount?

        add_error(field: :rate, error_code: "invalid_rate")
      end

      def fixed_amount
        properties["fixed_amount"]
      end

      def validate_fixed_amount
        return if fixed_amount.nil?
        return if ::Validators::DecimalAmountService.new(fixed_amount).valid_amount?

        add_error(field: :fixed_amount, error_code: "invalid_fixed_amount")
      end

      def free_units_per_events
        properties["free_units_per_events"]
      end

      def validate_free_units_per_events
        return if free_units_per_events.nil?
        return if free_units_per_events.is_a?(Integer) && free_units_per_events.positive?

        add_error(field: :free_units_per_events, error_code: "invalid_free_units_per_events")
      end

      def free_units_per_total_aggregation
        properties["free_units_per_total_aggregation"]
      end

      def validate_free_units_per_total_aggregation
        return if free_units_per_total_aggregation.nil?
        return if ::Validators::DecimalAmountService.new(free_units_per_total_aggregation).valid_amount?

        add_error(field: :free_units_per_total_aggregation, error_code: "invalid_free_units_per_total_aggregation")
      end

      def validate_per_transaction_min_max
        return unless License.premium?

        if properties["per_transaction_min_amount"].present? &&
            !::Validators::DecimalAmountService.valid_amount?(properties["per_transaction_min_amount"])
          add_error(field: :per_transaction_min_amount, error_code: "invalid_amount")
        end

        if properties["per_transaction_max_amount"].present? &&
            !::Validators::DecimalAmountService.valid_amount?(properties["per_transaction_max_amount"])
          add_error(field: :per_transaction_max_amount, error_code: "invalid_amount")
        end

        return if properties["per_transaction_min_amount"].nil? || properties["per_transaction_max_amount"].nil?
        return if BigDecimal(properties["per_transaction_min_amount"]) <=
          BigDecimal(properties["per_transaction_max_amount"])

        add_error(field: :per_transaction_max_amount, error_code: "per_transaction_max_lower_than_per_transaction_min")
      end
    end
  end
end
