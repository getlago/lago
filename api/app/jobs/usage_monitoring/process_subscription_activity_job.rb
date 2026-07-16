# frozen_string_literal: true

module UsageMonitoring
  class ProcessSubscriptionActivityJob < ApplicationJob
    queue_as :default

    def perform(subscription_activity_id, attempt = 1)
      subscription_activity = SubscriptionActivity.find_by(id: subscription_activity_id)
      return unless subscription_activity

      ProcessSubscriptionActivityService.call!(subscription_activity:)
    rescue => e
      Sentry.capture_exception(e) if defined?(Sentry)
      if attempt > 3
        SubscriptionActivity.where(id: subscription_activity_id).delete_all
        raise e
      end
      self.class.perform_later(subscription_activity_id, attempt + 1)
    end
  end
end
