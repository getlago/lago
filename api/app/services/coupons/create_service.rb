# frozen_string_literal: true

module Coupons
  class CreateService < BaseService
    Result = BaseResult[:coupon]

    def initialize(args)
      @args = args
      super
    end

    activity_loggable(
      action: "coupon.created",
      record: -> { result.coupon }
    )

    def call
      return result unless valid?(args)

      @limitations = args[:applies_to]&.to_h&.deep_symbolize_keys || {}
      @organization_id = args[:organization_id]

      reusable = args.key?(:reusable) ? args[:reusable] : true

      coupon = Coupon.new(
        organization_id:,
        name: args[:name],
        code: args[:code],
        description: args[:description],
        coupon_type: args[:coupon_type],
        amount_cents: args[:amount_cents],
        amount_currency: args[:amount_currency],
        percentage_rate: args[:percentage_rate],
        frequency: args[:frequency],
        frequency_duration: args[:frequency_duration],
        expiration: args[:expiration]&.to_sym,
        expiration_at: args[:expiration_at],
        limited_plans: plan_identifiers.present?,
        limited_billable_metrics: billable_metric_identifiers.present?,
        reusable:
      )

      if plan_identifiers.present? && (plan_identifiers - plans.pluck(plan_key)).present?
        return result.not_found_failure!(resource: "plans")
      end

      if billable_metric_identifiers.present? && billable_metrics.count != billable_metric_identifiers.count
        return result.not_found_failure!(resource: "billable_metrics")
      end

      if billable_metrics.present? && plans.present?
        return result.not_allowed_failure!(code: "only_one_limitation_type_per_coupon_allowed")
      end

      ActiveRecord::Base.transaction do
        coupon.save!

        plans.each { |plan| CouponTarget.create!(coupon:, plan:, organization_id:) } if plan_identifiers.present?

        if billable_metric_identifiers.present?
          billable_metrics.each { |bm| CouponTarget.create!(coupon:, billable_metric: bm, organization_id:) }
        end
      end

      result.coupon = coupon
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :args, :limitations, :organization_id

    def plan_identifiers
      key = api_context? ? :plan_codes : :plan_ids
      limitations[key]&.compact&.uniq
    end

    def plan_key
      api_context? ? :code : :id
    end

    def plans
      return @plans if defined? @plans
      return [] if plan_identifiers.blank?

      @plans = Plan.where(plan_key => plan_identifiers, :organization_id => organization_id)
    end

    def billable_metric_identifiers
      key = api_context? ? :billable_metric_codes : :billable_metric_ids
      limitations[key]&.compact&.uniq
    end

    def billable_metrics
      return @billable_metrics if defined? @billable_metrics
      return [] if billable_metric_identifiers.blank?

      @billable_metrics = if api_context?
        BillableMetric.where(code: billable_metric_identifiers, organization_id:)
      else
        BillableMetric.where(id: billable_metric_identifiers, organization_id:)
      end
    end

    def valid?(args)
      Coupons::ValidateService.new(result, **args).valid?
    end
  end
end
