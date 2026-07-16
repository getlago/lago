# frozen_string_literal: true

module UsageThresholds
  class OverrideService < BaseService
    Result = BaseResult[:usage_thresholds]

    def initialize(usage_thresholds_params:, new_plan:)
      @usage_thresholds_params = usage_thresholds_params
      @new_plan = new_plan

      super
    end

    def call
      ActiveRecord::Base.transaction do
        usage_thresholds_params.each do |params|
          usage_threshold = new_plan.usage_thresholds.new(
            organization_id: new_plan.organization_id,
            plan_id: new_plan.id,
            threshold_display_name: params[:threshold_display_name],
            amount_cents: params[:amount_cents],
            recurring: params[:recurring] || false
          )

          usage_threshold.save!
        end
      end

      result.usage_thresholds = new_plan.usage_thresholds
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :usage_thresholds_params, :new_plan
  end
end
