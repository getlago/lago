# frozen_string_literal: true

module Plans
  class UpdateUsageThresholdsService < BaseService
    Result = BaseResult[:plan]

    def initialize(plan:, usage_thresholds_params:)
      @plan = plan
      @usage_thresholds_params = usage_thresholds_params
      super
    end

    def call
      result.plan = plan
      return result unless plan.organization.progressive_billing_enabled?

      ActiveRecord::Base.transaction do
        UsageThresholds::UpdateService.call!(model: plan, usage_thresholds_params:, partial: false)
      end

      plan.usage_thresholds.reload
      LifetimeUsages::FlagRefreshFromPlanUpdateJob.perform_after_commit(plan) if plan.usage_thresholds.size > 0

      result
    end

    private

    attr_reader :plan, :usage_thresholds_params
  end
end
