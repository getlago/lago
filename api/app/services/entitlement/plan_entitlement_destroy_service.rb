# frozen_string_literal: true

module Entitlement
  class PlanEntitlementDestroyService < BaseService
    Result = BaseResult[:entitlement]

    def initialize(entitlement:)
      @entitlement = entitlement
      super
    end

    activity_loggable(
      action: "plan.updated",
      record: -> { entitlement&.plan }
    )

    def call
      return result.not_found_failure!(resource: "entitlement") unless entitlement

      ActiveRecord::Base.transaction do
        entitlement.values.discard_all!
        entitlement.discard!
      end

      SendWebhookJob.perform_after_commit("plan.updated", entitlement.plan)

      result.entitlement = entitlement
      result
    end

    private

    attr_reader :entitlement
  end
end
