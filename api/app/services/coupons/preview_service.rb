# frozen_string_literal: true

module Coupons
  class PreviewService < BaseService
    Result = BaseResult[:credits, :invoice]

    def initialize(invoice:, applied_coupons:)
      @invoice = invoice
      @applied_coupons = applied_coupons

      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") unless invoice
      return result.not_found_failure!(resource: "applied_coupons") unless applied_coupons

      result.credits = []

      applied_coupons.each do |applied_coupon|
        break unless invoice.sub_total_excluding_taxes_amount_cents&.positive?
        next if applied_coupon.coupon.fixed_amount? && invoice.currency != applied_coupon.amount_currency

        fees = fees(applied_coupon)

        next if fees.none?

        base_amount_cents = base_amount_cents(applied_coupon, fees)
        credit = add_credit(applied_coupon, fees, base_amount_cents)

        result.credits << credit
        invoice.credits << credit
      end

      result.invoice = invoice
      result
    end

    private

    attr_reader :applied_coupons, :invoice

    def add_credit(applied_coupon, fees, base_amount_cents)
      credit_amount = AppliedCoupons::AmountService.call(applied_coupon:, base_amount_cents:).amount
      new_credit = Credit.new(
        invoice:,
        organization_id: invoice.organization_id,
        applied_coupon:,
        amount_cents: credit_amount,
        amount_currency: invoice.currency,
        before_taxes: true
      )

      fees.each do |fee|
        unless base_amount_cents.zero?
          fee.precise_coupons_amount_cents += fee.compute_precise_credit_amount_cents(credit_amount, base_amount_cents)
        end

        fee.precise_coupons_amount_cents = fee.amount_cents if fee.amount_cents < fee.precise_coupons_amount_cents
      end

      invoice.coupons_amount_cents += new_credit.amount_cents
      invoice.sub_total_excluding_taxes_amount_cents -= new_credit.amount_cents

      new_credit
    end

    def base_amount_cents(applied_coupon, fees)
      if applied_coupon.coupon.limited_billable_metrics? || applied_coupon.coupon.limited_plans?
        fees.sum(&:amount_cents)
      else
        invoice.sub_total_excluding_taxes_amount_cents
      end
    end

    # TODO: update later when charges will be added to the preview
    def fees(applied_coupon)
      if applied_coupon.coupon.limited_billable_metrics?
        Fee.none
      elsif applied_coupon.coupon.limited_plans?
        plan_related_fees(applied_coupon)
      else
        invoice.fees
      end
    end

    def plan_related_fees(applied_coupon)
      if applied_coupon.coupon.plans.map(&:id).include?(invoice.subscriptions[0].plan_id)
        invoice.fees
      else
        Fee.none
      end
    end
  end
end
