# frozen_string_literal: true

module ChargeModels
  class CustomService < ChargeModels::BaseService
    protected

    def compute_amount
      aggregation_result.custom_aggregation&.[](:amount) || 0
    end

    def compute_projected_amount
      current_amount = compute_amount
      return BigDecimal("0") if current_amount.zero? || period_ratio.nil? || period_ratio.zero?

      current_amount / BigDecimal(period_ratio.to_s)
    end

    def unit_amount
      total_units = aggregation_result.full_units_number || units
      return 0 if total_units.zero?

      result.amount / total_units
    end
  end
end
