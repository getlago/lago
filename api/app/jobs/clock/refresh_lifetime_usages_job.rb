# frozen_string_literal: true

module Clock
  class RefreshLifetimeUsagesJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      return unless License.premium?

      Organization
        .with_progressive_billing_support
        .or(Organization.with_lifetime_usage_support)
        .find_each do |organization|
          LifetimeUsage
            .where(organization_id: organization.id)
            .where(recalculate_invoiced_usage: true)
            .find_each do |ltu|
              LifetimeUsages::RecalculateAndCheckJob.perform_later(ltu)
            end
        end
    end
  end
end
