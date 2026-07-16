# frozen_string_literal: true

module ChargeModels
  module AmountDetails
    class RangeGraduatedService < ::BaseService
      def initialize(range:, total_units:, adjacent_model: false)
        super
        @range = range
        @total_units = total_units
        @adjacent_model = adjacent_model
      end

      def call
        {
          from_value:,
          to_value:,
          flat_unit_amount:,
          per_unit_amount:,
          units: BigDecimal(units).to_s,
          per_unit_total_amount:,
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

      def per_unit_amount
        @per_unit_amount ||= units.zero? ? BigDecimal(0) : BigDecimal(range[:per_unit_amount])
      end

      def per_unit_total_amount
        @per_unit_total_amount ||= units * per_unit_amount
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
        effective_total = if to_value && BigDecimal(total_units.to_s) >= BigDecimal(to_value.to_s)
          BigDecimal(to_value.to_s)
        else
          BigDecimal(total_units.to_s)
        end

        return effective_total if BigDecimal(from_value.to_s).zero?

        diff = effective_total - BigDecimal(from_value.to_s)
        @adjacent_model ? diff : diff + 1
      end
    end
  end
end
