# frozen_string_literal: true

module Clock
  class ActivateSubscriptionsJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      Subscriptions::ActivateAllPendingService.call!(timestamp: Time.current.to_i)
    end
  end
end
