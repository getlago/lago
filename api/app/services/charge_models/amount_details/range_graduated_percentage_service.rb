# frozen_string_literal: true

module ChargeModels
  module AmountDetails
    class RangeGraduatedPercentageService < ::BaseService
      def initialize(range:, total_units:)
        super
        @range = range
        @total_units = total_units
      end

      def call
        {
          from_value:,
          to_value:,
          flat_unit_amount:,
          rate:,
          units: BigDecimal(units).to_s,
          per_unit_total_amount: per_unit_total_amount.to_s,
          total_with_flat_amount:
        }
      end

      protected

      attr_reader :range, :total_units

      def from_value
        @from_value ||= range[:from_value]
      end

      def to_value
        @to_value ||= range[:to_value]
      end

      def flat_unit_amount
        @flat_unit_amount ||= units.zero? ? BigDecimal(0) : BigDecimal(range[:flat_amount])
      end

      def rate
        @rate ||= BigDecimal(range[:rate].to_s)
      end

      def per_unit_total_amount
        @per_unit_total_amount ||= units * rate / 100
      end

      def total_with_flat_amount
        @total_with_flat_amount ||= if total_units.zero?
          per_unit_total_amount
        else
          per_unit_total_amount + flat_unit_amount
        end
      end

      # NOTE: compute how many units to bill in the range
      def units
        # NOTE: total_units is higher than the to_value of the range
        if to_value && total_units >= to_value
          return to_value - (from_value.zero? ? 1 : from_value) + 1
        end

        return to_value - from_value if to_value && total_units >= to_value
        return total_units if from_value.zero?

        # NOTE: total_units is in the range
        total_units - from_value + 1
      end
    end
  end
end
