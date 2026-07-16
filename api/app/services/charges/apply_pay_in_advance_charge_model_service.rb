# frozen_string_literal: true

module Charges
  class ApplyPayInAdvanceChargeModelService < BaseService
    def initialize(charge:, aggregation_result:, properties:)
      @charge = charge
      @aggregation_result = aggregation_result
      @properties = properties

      super
    end

    def call
      unless charge.pay_in_advance?
        return result.service_failure!(code: "apply_charge_model_error", message: "Charge is not pay_in_advance")
      end

      amount = if with_persisted_event?
        amount_from_aggregation - amount_excluding_persisted_event
      else
        amount_including_non_persisted_event - amount_from_aggregation
      end

      # NOTE: amount_result should be a BigDecimal, we need to round it
      # to the currency decimals and transform it into currency cents
      rounded_amount = amount.round(currency.exponent)
      amount_cents = rounded_amount * currency.subunit_to_unit

      result.units = compute_units
      result.count = 1
      result.amount = amount_cents
      result.precise_amount = amount * currency.subunit_to_unit.to_d
      result.unit_amount = rounded_amount.zero? ? BigDecimal(0) : rounded_amount / compute_units
      result.amount_details = calculated_single_event_amount_details if with_persisted_event?
      result
    end

    private

    attr_reader :charge, :aggregation_result, :properties

    def with_persisted_event?
      aggregation_result.pay_in_advance_event.persisted
    end

    def charge_model
      @charge_model ||= ChargeModels::Factory.in_advance_charge_model_class(chargeable: charge)
    end

    def applied_charge_model
      @applied_charge_model ||= charge_model.apply(charge:, aggregation_result:, properties:)
    end

    # Compute aggregation and apply charge for all events including the current one
    def amount_from_aggregation
      @amount_from_aggregation ||= applied_charge_model.amount
    end

    def applied_charge_model_excluding_persisted_event
      return @applied_charge_model_excluding_persisted_event if defined?(@applied_charge_model_excluding_persisted_event)

      precise_total_amount_cents = if aggregation_result.precise_total_amount_cents
        aggregation_result.precise_total_amount_cents - aggregation_result.pay_in_advance_precise_total_amount_cents
      end

      result_without_event = build_aggregation_result(
        aggregation: aggregation_result.aggregation - aggregation_result.pay_in_advance_aggregation,
        count: aggregation_result.count - 1,
        precise_total_amount_cents:
      )

      @applied_charge_model_excluding_persisted_event ||= charge_model.apply(
        charge:,
        aggregation_result: result_without_event,
        properties: (properties || {}).merge(exclude_event: true)
      )
    end

    # Compute aggregation and apply charge for all events excluding the current one
    def amount_excluding_persisted_event
      applied_charge_model_excluding_persisted_event.amount
    end

    def applied_charge_model_including_non_persisted_event
      return @applied_charge_model_including_non_persisted_event if defined?(@applied_charge_model_including_non_persisted_event)

      precise_total_amount_cents = if aggregation_result.precise_total_amount_cents
        aggregation_result.precise_total_amount_cents + aggregation_result.pay_in_advance_precise_total_amount_cents
      end

      result_with_event = build_aggregation_result(
        aggregation: aggregation_result.aggregation + aggregation_result.pay_in_advance_aggregation,
        count: aggregation_result.count + 1,
        precise_total_amount_cents:
      )

      @applied_charge_model_including_non_persisted_event ||= charge_model.apply(
        charge:,
        aggregation_result: result_with_event,
        properties: (properties || {}).merge(include_event_value: true)
      )
    end

    def amount_including_non_persisted_event
      applied_charge_model_including_non_persisted_event.amount
    end

    def currency
      @currency ||= charge.plan.amount.currency
    end

    def compute_units
      if display_applied_units_for_zero_invoice?
        units_applied = BigDecimal(aggregation_result.units_applied)
        units_applied.negative? ? 0 : units_applied
      elsif charge.prorated?
        aggregation_result.full_units_number
      else
        aggregation_result.pay_in_advance_aggregation
      end
    end

    def display_applied_units_for_zero_invoice?
      aggregation_result.current_aggregation &&
        aggregation_result.max_aggregation &&
        aggregation_result.units_applied &&
        aggregation_result.current_aggregation <= aggregation_result.max_aggregation
    end

    def calculated_single_event_amount_details
      PayInAdvance::AmountDetailsCalculator.call(
        charge:,
        applied_charge_model:,
        applied_charge_model_excluding_event: applied_charge_model_excluding_persisted_event
      )
    end

    def build_aggregation_result(aggregation:, count:, precise_total_amount_cents:)
      new_result = BillableMetrics::Aggregations::BaseService::Result.new
      new_result.aggregation = aggregation
      new_result.count = count
      new_result.options = aggregation_result.options
      new_result.aggregator = aggregation_result.aggregator
      new_result.pay_in_advance_event = aggregation_result.pay_in_advance_event
      new_result.precise_total_amount_cents = precise_total_amount_cents
      new_result
    end
  end
end
