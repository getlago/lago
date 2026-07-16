# frozen_string_literal: true

module UsageMonitoring
  class ProcessAllSubscriptionActivitiesService < BaseService
    Result = BaseResult

    def call
      # NOTE: If we need to handle different delays per organization, this would be done here.
      #     This is also where we should report metrics
      #     That's why it's a dedicated service and not just done in the job

      scope = SubscriptionActivity.where(enqueued: false)

      dedicated_org_ids = Utils::DedicatedWorkerConfig.organization_ids
      scope = scope.where.not(organization_id: dedicated_org_ids) if dedicated_org_ids.any?

      scope.distinct.pluck(:organization_id).each do |organization_id|
        ProcessOrganizationSubscriptionActivitiesJob.perform_later(organization_id)
      end

      result
    end
  end
end
