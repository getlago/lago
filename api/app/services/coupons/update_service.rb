# frozen_string_literal: true

module Coupons
  class UpdateService < BaseService
    Result = BaseResult[:coupon]

    def initialize(coupon:, params:)
      @coupon = coupon
      @params = params

      super
    end

    activity_loggable(
      action: "coupon.updated",
      record: -> { coupon }
    )

    def call
      return result.not_found_failure!(resource: "coupon") unless coupon
      return result unless valid?(params)

      coupon.name = params[:name] if params.key?(:name)
      coupon.description = params[:description] if params.key?(:description)
      coupon.expiration = params[:expiration]&.to_sym if params.key?(:expiration)
      coupon.expiration_at = params[:expiration_at] if params.key?(:expiration_at)

      @limitations = params[:applies_to]&.to_h&.deep_symbolize_keys || {}
      coupon_already_applied = coupon.applied_coupons.exists?

      unless coupon_already_applied
        if !plan_identifiers.nil? && plans.count != plan_identifiers.count
          return result.not_found_failure!(resource: "plans")
        end

        if !billable_metric_identifiers.nil? && billable_metrics.count != billable_metric_identifiers.count
          return result.not_found_failure!(resource: "billable_metrics")
        end

        if billable_metrics.present? && plans.present?
          return result.not_allowed_failure!(code: "only_one_limitation_type_per_coupon_allowed")
        end

        if coupon.billable_metrics.exists? && plans.present? && billable_metrics.blank?
          coupon.limited_billable_metrics = false
        elsif !billable_metric_identifiers.nil?
          coupon.limited_billable_metrics = billable_metric_identifiers.present?
        end

        if coupon.plans.exists? && billable_metrics.present? && plans.blank?
          coupon.limited_plans = false
        elsif !plan_identifiers.nil?
          coupon.limited_plans = plan_identifiers.present?
        end

        coupon.code = params[:code] if params.key?(:code)
        coupon.coupon_type = params[:coupon_type] if params.key?(:coupon_type)
        coupon.amount_cents = params[:amount_cents] if params.key?(:amount_cents)
        coupon.amount_currency = params[:amount_currency] if params.key?(:amount_currency)
        coupon.percentage_rate = params[:percentage_rate] if params.key?(:percentage_rate)
        coupon.frequency = params[:frequency] if params.key?(:frequency)
        coupon.frequency_duration = params[:frequency_duration] if params.key?(:frequency_duration)
        coupon.reusable = params[:reusable] if params.key?(:reusable)
      end

      ActiveRecord::Base.transaction do
        coupon.save!

        process_plans unless coupon_already_applied
        process_billable_metrics unless coupon_already_applied
      end

      result.coupon = coupon
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :coupon, :params, :limitations

    delegate :organization, to: :coupon

    def plan_identifiers
      key = api_context? ? :plan_codes : :plan_ids
      limitations[key]&.compact&.uniq
    end

    def plans
      return @plans if defined? @plans
      return [] if plan_identifiers.blank?

      @plans = if api_context?
        Plan.where(code: plan_identifiers, organization_id: coupon.organization_id)
      else
        Plan.where(id: plan_identifiers, organization_id: coupon.organization_id)
      end
    end

    def process_plans
      existing_coupon_plan_ids = coupon.coupon_targets.pluck(:plan_id).compact

      plans.each do |plan|
        next if existing_coupon_plan_ids.include?(plan.id)

        CouponTarget.create!(coupon:, plan:, organization_id: organization.id)
      end

      sanitize_coupon_plans
    end

    def sanitize_coupon_plans
      not_needed_coupon_plan_ids = coupon.coupon_targets.pluck(:plan_id).compact - plans.pluck(:id)

      not_needed_coupon_plan_ids.each do |coupon_plan_id|
        CouponTarget.find_by(coupon:, plan_id: coupon_plan_id).destroy!
      end
    end

    def billable_metric_identifiers
      key = api_context? ? :billable_metric_codes : :billable_metric_ids
      limitations[key]&.compact&.uniq
    end

    def billable_metrics
      return @billable_metrics if defined? @billable_metrics
      return [] if billable_metric_identifiers.blank?

      @billable_metrics = if api_context?
        BillableMetric.where(code: billable_metric_identifiers, organization_id: coupon.organization_id)
      else
        BillableMetric.where(id: billable_metric_identifiers, organization_id: coupon.organization_id)
      end
    end

    def process_billable_metrics
      existing_coupon_billable_metric_ids = coupon.coupon_targets.pluck(:billable_metric_id).compact

      billable_metrics.each do |billable_metric|
        next if existing_coupon_billable_metric_ids.include?(billable_metric.id)

        CouponTarget.create!(coupon:, billable_metric:, organization_id: organization.id)
      end

      sanitize_coupon_billable_metrics
    end

    def sanitize_coupon_billable_metrics
      not_needed_coupon_billable_metric_ids =
        coupon.coupon_targets.pluck(:billable_metric_id).compact - billable_metrics.pluck(:id)

      not_needed_coupon_billable_metric_ids.each do |coupon_billable_metric_id|
        CouponTarget.find_by(coupon:, billable_metric_id: coupon_billable_metric_id).destroy!
      end
    end

    def valid?(args)
      Coupons::ValidateService.new(result, **args).valid?
    end
  end
end
