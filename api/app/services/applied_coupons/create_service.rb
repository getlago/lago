# frozen_string_literal: true

module AppliedCoupons
  class CreateService < BaseService
    Result = BaseResult[:applied_coupon]

    def initialize(customer:, coupon:, params:)
      @customer = customer
      @coupon = coupon
      @params = params

      super
    end

    activity_loggable(
      action: "applied_coupon.created",
      record: -> { result.applied_coupon }
    )

    def call
      check_preconditions
      return result if result.error

      applied_coupon = AppliedCoupon.new(
        customer:,
        coupon:,
        organization: customer.organization,
        amount_cents: params[:amount_cents] || coupon.amount_cents,
        amount_currency: params[:amount_currency] || coupon.amount_currency,
        percentage_rate: params[:percentage_rate] || coupon.percentage_rate,
        frequency: params[:frequency] || coupon.frequency,
        frequency_duration: params[:frequency_duration] || coupon.frequency_duration,
        frequency_duration_remaining: params[:frequency_duration] || coupon.frequency_duration
      )

      if coupon.fixed_amount?
        ActiveRecord::Base.transaction do
          Customers::UpdateCurrencyService
            .call(customer:, currency: params[:amount_currency] || coupon.amount_currency)
            .raise_if_error!

          applied_coupon.save!
        end
      else
        applied_coupon.save!
      end

      result.applied_coupon = applied_coupon
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :customer, :coupon, :params

    def check_preconditions
      return result.not_found_failure!(resource: "customer") unless customer
      return result.not_found_failure!(resource: "coupon") unless coupon&.active?
      return result.not_allowed_failure!(code: "plan_overlapping") if plan_limitation_overlapping?
      return if reusable_coupon?

      result.single_validation_failure!(field: "coupon", error_code: "coupon_is_not_reusable")
    end

    def reusable_coupon?
      return true if coupon.reusable?

      customer.applied_coupons.where(coupon_id: coupon.id).none?
    end

    def plan_limitation_overlapping?
      return false if !coupon.limited_plans? && !coupon.limited_billable_metrics?

      relation = customer
        .applied_coupons
        .active
        .joins(coupon: :coupon_targets)

      relation
        .where(coupon_targets: {plan_id: coupon.coupon_targets.select(:plan_id)})
        .or(relation.where(coupon_targets: {billable_metric_id: coupon.coupon_targets.select(:billable_metric_id)}))
        .or(relation.where(coupon_targets: {plan_id: plans_from_billable_metric_limitations}))
        .or(relation.where(coupon_targets: {billable_metric_id: billable_metrics_from_plan_limitations}))
        .exists?
    end

    def billable_metrics_from_plan_limitations
      Charge
        .joins(:plan)
        .where(plan: {id: coupon.coupon_targets.select(:plan_id)})
        .select(:billable_metric_id)
    end

    def plans_from_billable_metric_limitations
      Charge
        .joins(:billable_metric)
        .where(billable_metric: {id: coupon.coupon_targets.select(:billable_metric_id)})
        .select(:plan_id)
    end
  end
end
