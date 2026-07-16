# frozen_string_literal: true

module Credits
  class AppliedCouponService < BaseService
    Result = BaseResult[:credit]

    def initialize(invoice:, applied_coupon:)
      @invoice = invoice
      @applied_coupon = applied_coupon

      super(nil)
    end

    def call
      if !AppliedCoupons::LockService.new(customer:).locked?
        return result.service_failure!(code: "no_lock_acquired", message: "Calling this service without acquiring a lock is not allowed")
      end

      return result unless matches_currency?
      return result if already_applied?
      return result unless fees.any?

      credit_amount = AppliedCoupons::AmountService.call(applied_coupon:, base_amount_cents:).amount

      new_credit = Credit.create!(
        organization_id: invoice.organization_id,
        invoice:,
        applied_coupon:,
        amount_cents: credit_amount,
        amount_currency: invoice.currency,
        before_taxes: true
      )

      weighting_base_amount_cents = base_amount_cents # Ensure that base remains the same during weighting process
      fees.reload.each do |fee|
        unless weighting_base_amount_cents.zero?
          fee.precise_coupons_amount_cents += fee.compute_precise_credit_amount_cents(credit_amount, weighting_base_amount_cents)
        end

        fee.precise_coupons_amount_cents = fee.amount_cents if fee.amount_cents < fee.precise_coupons_amount_cents
        fee.save!
      end

      decrement_frequency_duration_remaining if applied_coupon.recurring?

      if should_terminate_applied_coupon?(credit_amount)
        applied_coupon.mark_as_terminated!
      elsif applied_coupon.recurring?
        applied_coupon.save!
      end

      invoice.coupons_amount_cents += new_credit.amount_cents
      invoice.sub_total_excluding_taxes_amount_cents -= new_credit.amount_cents

      result.credit = new_credit
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_accessor :invoice, :applied_coupon

    delegate :coupon, to: :applied_coupon
    delegate :customer, to: :invoice

    def matches_currency?
      return true if coupon.percentage?

      applied_coupon.amount_currency == invoice.currency
    end

    def already_applied?
      invoice.credits.where(applied_coupon_id: applied_coupon.id).exists?
    end

    def should_terminate_applied_coupon?(credit_amount)
      return false if applied_coupon.forever?

      if applied_coupon.once?
        applied_coupon.coupon.percentage? || credit_amount >= applied_coupon.remaining_amount
      else
        applied_coupon.frequency_duration_remaining <= 0
      end
    end

    def decrement_frequency_duration_remaining
      applied_coupon.frequency_duration_remaining = [applied_coupon.frequency_duration_remaining.to_i - 1, 0].max
    end

    # TODO: ensure targeted amount is right with BM/plan limitation
    def base_amount_cents
      if applied_coupon.coupon.limited_billable_metrics? || applied_coupon.coupon.limited_plans?
        amount = 0
        fees.each do |fee|
          amount += fee.amount_cents - fee.precise_coupons_amount_cents
        end

        return amount
      end

      invoice.sub_total_excluding_taxes_amount_cents
    end

    def fees
      @fees ||= if applied_coupon.coupon.limited_billable_metrics?
        billable_metric_related_fees
      elsif applied_coupon.coupon.limited_plans?
        plan_related_fees
      else
        invoice.fees
      end
    end

    def plan_related_fees
      invoice
        .fees
        .joins(subscription: :plan)
        .where(plan: {id: applied_coupon.coupon.parent_and_overriden_plans.map(&:id)})
    end

    def billable_metric_related_fees
      invoice
        .fees
        .joins(charge: :billable_metric)
        .where(billable_metric: {id: applied_coupon.coupon.coupon_targets.select(:billable_metric_id)})
    end
  end
end
