# frozen_string_literal: true

module Plans
  class PrepareDestroyService < BaseService
    Result = BaseResult[:plan]

    def initialize(plan:)
      @plan = plan
      super
    end

    def call
      return result.not_found_failure!(resource: "plan") unless plan

      ActiveRecord::Base.transaction do
        plan.update!(pending_deletion: true)
        plan.children.update_all(pending_deletion: true) # rubocop:disable Rails/SkipsModelValidations
        Plans::DestroyJob.perform_later(plan)
      end

      SendWebhookJob.perform_after_commit("plan.deleted", plan)

      result.plan = plan
      result
    end

    private

    attr_reader :plan
  end
end
