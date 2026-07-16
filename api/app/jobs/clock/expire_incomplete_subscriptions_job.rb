# frozen_string_literal: true

module Clock
  class ExpireIncompleteSubscriptionsJob < ClockJob
    unique :until_executed, on_conflict: :log, lock_ttl: 4.hours

    def perform
      Subscription.expirable.find_each do |subscription|
        Subscriptions::ActivationRules::ExpireIncompleteJob.perform_later(subscription)
      end
    end
  end
end
