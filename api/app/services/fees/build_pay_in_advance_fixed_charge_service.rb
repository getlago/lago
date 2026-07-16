# frozen_string_literal: true

module Fees
  class BuildPayInAdvanceFixedChargeService < BaseService
    Result = BaseResult[:fee]

    def initialize(subscription:, fixed_charge:, fixed_charge_event:, timestamp:)
      @subscription = subscription
      @fixed_charge = fixed_charge
      @fixed_charge_event = fixed_charge_event
      @timestamp = timestamp
      @organization = subscription.organization
      @currency = subscription.plan.amount.currency

      super
    end

    def call
      # Calculate boundaries for the current billing period
      boundaries = calculate_boundaries

      # Find already paid units for this fixed charge in the current billing period
      already_paid_units = find_already_paid_units(boundaries)

      # Calculate delta (new units - already paid)
      new_units = fixed_charge_event.units
      delta_units = new_units - already_paid_units

      # If delta is negative or zero (decrease), create a zero-amount fee
      # We don't refund pay-in-advance, but we still generate an invoice to document the change
      if delta_units <= 0
        fee = build_zero_amount_fee(boundaries)
        result.fee = fee
        return result
      end

      # Calculate the fee for the delta units (positive increase)
      fee = build_delta_fee(delta_units, boundaries)
      result.fee = fee
      result
    end

    private

    attr_reader :subscription, :fixed_charge, :fixed_charge_event, :timestamp, :organization, :currency

    def calculate_boundaries
      dates = Subscriptions::DatesService.fixed_charge_pay_in_advance_interval(timestamp, subscription)

      BillingPeriodBoundaries.new(
        from_datetime: dates[:fixed_charges_from_datetime],
        to_datetime: dates[:fixed_charges_to_datetime],
        charges_from_datetime: nil,
        charges_to_datetime: nil,
        fixed_charges_from_datetime: dates[:fixed_charges_from_datetime],
        fixed_charges_to_datetime: dates[:fixed_charges_to_datetime],
        timestamp: Time.zone.at(timestamp),
        charges_duration: nil,
        fixed_charges_duration: dates[:fixed_charges_duration]
      )
    end

    def find_already_paid_units(boundaries)
      # Find fees for this fixed charge that have already been paid in this billing period
      existing_fees = Fee.where(
        organization:,
        subscription:,
        fixed_charge: [fixed_charge, fixed_charge.parent],
        fee_type: :fixed_charge
      ).where(
        "properties->>'fixed_charges_from_datetime' = ?",
        boundaries.fixed_charges_from_datetime.iso8601(3)
      ).where(
        "properties->>'fixed_charges_to_datetime' = ?",
        boundaries.fixed_charges_to_datetime.iso8601(3)
      )

      # Sum up all the units that have been billed for this period
      existing_fees.sum(:units).to_d
    end

    def build_delta_fee(delta_units, boundaries)
      proration_coefficient = if fixed_charge.prorated?
        days = (boundaries.fixed_charges_to_datetime.to_date - Time.zone.at(timestamp).to_date + 1)
        days / boundaries.fixed_charges_duration.to_f
      else
        1
      end

      # Apply the charge model to calculate the amount for delta units
      amount_result = calculate_amount_for_units(delta_units * proration_coefficient)

      rounded_amount = amount_result[:amount].round(currency.exponent)
      amount_cents = rounded_amount * currency.subunit_to_unit
      precise_amount_cents = amount_result[:amount] * currency.subunit_to_unit.to_d
      unit_amount_cents = delta_units.positive? ? (amount_cents / delta_units).round : 0
      precise_unit_amount = delta_units.positive? ? (amount_result[:amount] / delta_units) : BigDecimal("0")

      Fee.new(
        organization:,
        billing_entity_id: subscription.applicable_billing_entity_id,
        subscription:,
        fixed_charge:,
        amount_cents:,
        precise_amount_cents:,
        amount_currency: currency,
        fee_type: :fixed_charge,
        invoiceable_type: "FixedCharge",
        invoiceable: fixed_charge,
        units: delta_units,
        total_aggregated_units: delta_units,
        properties: boundaries.to_h,
        payment_status: :pending,
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: BigDecimal("0"),
        unit_amount_cents:,
        precise_unit_amount:,
        amount_details: {},
        pay_in_advance: true
      )
    end

    def calculate_amount_for_units(units)
      # Create a mock aggregation result for the charge model
      aggregation_result = BaseService::Result.new
      aggregation_result.aggregation = units
      aggregation_result.full_units_number = units
      aggregation_result.count = 1

      charge_model_result = ChargeModels::Factory.new_instance(
        chargeable: fixed_charge,
        aggregation_result:,
        properties: fixed_charge.properties,
        period_ratio: 1.0,
        calculate_projected_usage: false
      ).apply

      {amount: charge_model_result.amount, unit_amount: charge_model_result.unit_amount}
    end

    def build_zero_amount_fee(boundaries)
      Fee.new(
        organization:,
        billing_entity_id: subscription.applicable_billing_entity_id,
        subscription:,
        fixed_charge:,
        amount_cents: 0,
        precise_amount_cents: BigDecimal("0"),
        amount_currency: currency,
        fee_type: :fixed_charge,
        invoiceable_type: "FixedCharge",
        invoiceable: fixed_charge,
        units: 0,
        total_aggregated_units: 0,
        properties: boundaries.to_h,
        payment_status: :pending,
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: BigDecimal("0"),
        unit_amount_cents: 0,
        precise_unit_amount: BigDecimal("0"),
        amount_details: {},
        pay_in_advance: true
      )
    end
  end
end
