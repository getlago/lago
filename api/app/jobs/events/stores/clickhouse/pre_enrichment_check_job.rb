# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      class PreEnrichmentCheckJob < ApplicationJob
        queue_as "low_priority"

        def perform(subscription_id:, codes:, batch_size:, sleep_seconds:)
          subscription = Subscription.find_by(id: subscription_id)
          return unless subscription

          ReEnrichSubscriptionEventsService.call!(
            subscription:, codes:, reprocess: true, batch_size:, sleep_seconds:
          )
        end
      end
    end
  end
end
