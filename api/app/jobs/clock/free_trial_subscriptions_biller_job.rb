# frozen_string_literal: true

module Clock
  class FreeTrialSubscriptionsBillerJob < ClockJob
    unique :until_executed, on_conflict: :log, lock_ttl: 4.hours

    def perform
      Subscriptions::FreeTrialBillingService.call
    end
  end
end
