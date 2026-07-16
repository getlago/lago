# frozen_string_literal: true

module ChargeModels
  class DynamicService < ChargeModels::BaseService
    protected

    def compute_amount
      total_units = aggregation_result.full_units_number || units
      return 0 if total_units.zero?

      amount_cents = aggregation_result.precise_total_amount_cents
      amount_cents / currency.subunit_to_unit
    end

    def unit_amount
      # eventhough `full_units_number` is not set by the SumService, we still keep this code as is, to be future proof
      total_units = aggregation_result.full_units_number || units
      return 0 if total_units.zero?

      compute_amount / total_units
    end

    def compute_projected_amount
      current_amount = compute_amount
      return BigDecimal("0") if current_amount.zero? || period_ratio.nil? || period_ratio.zero?

      current_amount / BigDecimal(period_ratio.to_s)
    end

    private

    def currency
      charge.plan.amount.currency
    end
  end
end
