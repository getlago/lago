# frozen_string_literal: true

module Charges
  module Validators
    class GraduatedService < Charges::Validators::BaseService
      include ::Validators::RangeBoundsValidator

      def valid?
        if ranges.blank?
          add_error(field: :graduated_ranges, error_code: "missing_graduated_ranges")
        else
          next_from_value = 0
          ranges.each_with_index do |range, index|
            validate_amounts(range)

            unless valid_bounds?(range, index, next_from_value)
              add_error(field: :graduated_ranges, error_code: "invalid_graduated_ranges")
            end

            next_from_value = range[:to_value] || 0
          end
        end

        super
      end

      private

      def ranges
        (properties["graduated_ranges"] || []).map(&:with_indifferent_access)
      end

      def validate_amounts(range)
        unless ::Validators::DecimalAmountService.new(range[:per_unit_amount]).valid_amount?
          add_error(field: :per_unit_amount, error_code: "invalid_amount")
        end

        return if ::Validators::DecimalAmountService.new(range[:flat_amount]).valid_amount?

        add_error(field: :flat_amount, error_code: "invalid_amount")
      end
    end
  end
end
