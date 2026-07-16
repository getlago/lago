# frozen_string_literal: true

module ChargeModels
  class GraduatedService < ChargeModels::BaseService
    protected

    def ranges
      properties["graduated_ranges"]&.map(&:with_indifferent_access)
    end

    def amount_details
      {
        graduated_ranges: ranges.each_with_object([]) do |range, amounts|
          amounts << ChargeModels::AmountDetails::RangeGraduatedService.call(range:, total_units: units, adjacent_model: adjacent_ranges?)
          break amounts if range[:to_value].nil? || range[:to_value] >= units
        end
      }
    end

    def adjacent_ranges?
      return false if ranges.size < 2

      ranges.each_cons(2).all? do |prev, curr|
        BigDecimal(curr[:from_value].to_s) == BigDecimal((prev[:to_value] || 0).to_s)
      end
    end

    def compute_amount
      amount_details.fetch(:graduated_ranges).sum { |e| e[:total_with_flat_amount] }
    end

    def compute_projected_amount
      return BigDecimal("0") if projected_units.zero?

      remaining_units_to_price = projected_units
      total_amount = BigDecimal("0")

      priced_units_count = BigDecimal("0")

      ranges.each do |range|
        range_to = range[:to_value] ? BigDecimal(range[:to_value].to_s) : Float::INFINITY
        tier_capacity = range_to - priced_units_count
        units_in_this_tier = [remaining_units_to_price, tier_capacity].min

        if units_in_this_tier > 0
          range_per_unit = BigDecimal(range[:per_unit_amount] || 0)
          range_flat_amount = BigDecimal(range[:flat_amount] || 0)
          range_amount = (units_in_this_tier * range_per_unit) + range_flat_amount
          total_amount += range_amount
          remaining_units_to_price -= units_in_this_tier
          priced_units_count += units_in_this_tier
        end
        break if remaining_units_to_price <= 0
      end

      total_amount
    end

    def unit_amount
      total_units = aggregation_result.full_units_number || units
      return 0 if total_units.zero?

      compute_amount / total_units
    end
  end
end
