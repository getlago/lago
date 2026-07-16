# frozen_string_literal: true

module Charges
  module Validators
    class GraduatedPercentageService < Charges::Validators::BaseService
      include ::Validators::RangeBoundsValidator

      def valid?
        validate_billable_metric

        if ranges.blank?
          add_error(field: :graduated_percentage_ranges, error_code: "missing_graduated_percentage_ranges")
        else
          next_from_value = 0

          ranges.each_with_index do |range, index|
            validate_rate_and_amounts(range)

            unless valid_bounds?(range, index, next_from_value)
              add_error(field: :graduated_percentage_ranges, error_code: "invalid_graduated_percentage_ranges")
            end

            next_from_value = range[:to_value] || 0
          end
        end

        super
      end

      private

      def validate_billable_metric
        return unless charge.billable_metric.latest_agg?

        add_error(field: :billable_metric, error_code: "invalid_value")
      end

      def ranges
        properties["graduated_percentage_ranges"].map(&:with_indifferent_access)
      end

      def validate_rate_and_amounts(range)
        unless ::Validators::DecimalAmountService.valid_amount?(range[:flat_amount])
          add_error(field: :flat_amount, error_code: "invalid_amount")
        end

        return if ::Validators::DecimalAmountService.valid_amount?(range[:rate])

        add_error(field: :rate, error_code: "invalid_rate")
      end
    end
  end
end
