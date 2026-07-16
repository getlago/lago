# frozen_string_literal: true

module Clock
  class InboundWebhooksCleanupJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      InboundWebhook.where("updated_at < ?", 90.days.ago).in_batches.delete_all
    end
  end
end
