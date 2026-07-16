# frozen_string_literal: true

module Fees
  class CreateTrueUpService < BaseService
    Result = BaseResult[:true_up_fee]

    def initialize(fee:, used_amount_cents:, used_precise_amount_cents:)
      @fee = fee
      @used_amount_cents = used_amount_cents
      @used_precise_amount_cents = used_precise_amount_cents
      @boundaries = BillingPeriodBoundaries.from_fee(fee)

      super
    end

    def call
      return result unless fee
      return result if used_amount_cents >= prorated_min_amount_cents

      if charge.applied_pricing_unit
        amount_cents, precise_amount_cents, unit_amount_cents, precise_unit_amount = pricing_unit_usage
          .to_fiat_currency_cents(charge.plan.amount.currency)
          .values_at(:amount_cents, :precise_amount_cents, :unit_amount_cents, :precise_unit_amount)
      else
        amount_cents = (prorated_min_amount_cents - used_amount_cents).round
        precise_amount_cents = prorated_min_amount_cents - used_precise_amount_cents
        unit_amount_cents = amount_cents
        precise_unit_amount = precise_amount_cents / charge.plan.amount.currency.subunit_to_unit
      end

      true_up_fee = fee.dup
      true_up_fee.assign_attributes(
        amount_cents:,
        precise_amount_cents:,
        units: 1,
        total_aggregated_units: 1,
        events_count: 0,
        charge_filter_id: nil,
        true_up_parent_fee: fee,
        unit_amount_cents:,
        precise_unit_amount:,
        pricing_unit_usage:
      )

      result.true_up_fee = true_up_fee
      result
    end

    private

    attr_reader :fee, :used_amount_cents, :used_precise_amount_cents, :boundaries

    delegate :charge, :subscription, to: :fee

    def prorated_min_amount_cents
      # NOTE: number of days between beginning of the period and the termination date
      from_datetime = boundaries.charges_from_datetime.to_time
      to_datetime = boundaries.charges_to_datetime.to_time
      number_of_day_to_bill = subscription.date_diff_with_timezone(from_datetime, to_datetime)

      charge.min_amount_cents.fdiv(boundaries.charges_duration) * number_of_day_to_bill
    end

    def pricing_unit_usage
      return @pricing_unit_usage if defined?(@pricing_unit_usage)

      unless charge.applied_pricing_unit
        @pricing_unit_usage = nil
        return
      end

      amount_cents = prorated_min_amount_cents - used_amount_cents
      precise_amount_cents = prorated_min_amount_cents - used_precise_amount_cents

      @pricing_unit_usage = PricingUnitUsage.build_from_fiat_amounts(
        amount: amount_cents / charge.pricing_unit.subunit_to_unit.to_d,
        unit_amount: precise_amount_cents / charge.pricing_unit.subunit_to_unit.to_d,
        applied_pricing_unit: charge.applied_pricing_unit
      )
    end
  end
end
