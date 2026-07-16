# frozen_string_literal: true

module Entitlement
  class PrivilegeDestroyService < BaseService
    Result = BaseResult[:privilege]

    def initialize(privilege:)
      @privilege = privilege
      super
    end

    activity_loggable(
      action: "feature.updated",
      record: -> { privilege&.feature }
    )

    def call
      return result.not_found_failure!(resource: "privilege") unless privilege

      ActiveRecord::Base.transaction do
        privilege.values.discard_all!
        privilege.discard!
      end

      jobs = privilege.feature.plans.map do |plan|
        Utils::ActivityLog.produce_after_commit(plan, "plan.updated")
        SendWebhookJob.new("plan.updated", plan)
      end

      after_commit do
        ApplicationJob.perform_all_later(jobs)
        SendWebhookJob.perform_later("feature.updated", privilege.feature)
      end

      result.privilege = privilege
      result
    end

    private

    attr_reader :privilege
  end
end
