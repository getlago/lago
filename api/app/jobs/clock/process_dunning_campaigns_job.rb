# frozen_string_literal: true

module Clock
  class ProcessDunningCampaignsJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      return unless License.premium?

      DunningCampaigns::BulkProcessJob.perform_later
    end
  end
end
