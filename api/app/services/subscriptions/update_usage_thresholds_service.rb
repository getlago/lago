# frozen_string_literal: true

module Subscriptions
  class UpdateUsageThresholdsService < BaseService
    Result = BaseResult

    def initialize(subscription:, usage_thresholds_params:, partial:)
      @subscription = subscription
      @usage_thresholds_params = usage_thresholds_params
      @partial = partial
      super
    end

    def call
      return result unless subscription.organization.progressive_billing_enabled?

      ActiveRecord::Base.transaction do
        UsageThresholds::UpdateService.call!(model: subscription, usage_thresholds_params:, partial:)
        # NOTE: Once we attach UT to the subscription, we should delete all UT attached to the plan override
        plan.usage_thresholds.update_all(deleted_at: Time.current) if plan.is_child? # rubocop:disable Rails/SkipsModelValidations
      end

      subscription.usage_thresholds.reload
      subscription&.lifetime_usage&.update recalculate_invoiced_usage: true if subscription.usage_thresholds.size > 0

      result
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :subscription, :usage_thresholds_params, :partial
    delegate :plan, to: :subscription
  end
end
