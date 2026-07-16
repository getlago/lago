# frozen_string_literal: true

module Clock
  class ProcessDedicatedOrgsSubscriptionActivitiesJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      return unless License.premium?

      organization_ids = Utils::DedicatedWorkerConfig.organization_ids
      return if organization_ids.empty?

      UsageMonitoring::SubscriptionActivity
        .where(organization_id: organization_ids, enqueued: false)
        .distinct
        .pluck(:organization_id)
        .each do |organization_id|
          UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob.perform_later(organization_id)
        end
    end
  end
end
