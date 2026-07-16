# frozen_string_literal: true

module Entitlement
  class FeatureDestroyService < BaseService
    Result = BaseResult[:feature]

    def initialize(feature:)
      @feature = feature
      super
    end

    activity_loggable(
      action: "feature.deleted",
      record: -> { result.feature }
    )

    def call
      return result.not_found_failure!(resource: "feature") unless feature

      plans = feature.plans.to_a

      ActiveRecord::Base.transaction do
        feature.entitlement_values.discard_all!
        feature.entitlements.discard_all!
        feature.privileges.discard_all!
        feature.discard!
      end

      jobs = []
      plans.each do |plan|
        Utils::ActivityLog.produce_after_commit(plan, "plan.updated")
        jobs << SendWebhookJob.new("plan.updated", plan)
      end

      after_commit do
        ApplicationJob.perform_all_later(jobs)
        SendWebhookJob.perform_later("feature.deleted", feature)
      end

      result.feature = feature
      result
    end

    private

    attr_reader :feature
  end
end
