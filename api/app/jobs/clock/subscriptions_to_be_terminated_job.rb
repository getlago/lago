# frozen_string_literal: true

module Clock
  class SubscriptionsToBeTerminatedJob < ClockJob
    unique :until_executed, on_conflict: :log, lock_ttl: 4.hours

    def perform
      now = Time.current
      today = now.to_date

      Subscription
        .active
        .where("DATE(ending_at::timestamptz) IN (?)", sent_at_dates(now))
        .in_batches do |subscriptions|
          subscriptions = subscriptions.to_a
          subscription_ids_already_alerted = Webhook.where(
            webhook_type: "subscription.termination_alert",
            object_type: "Subscription",
            object_id: subscriptions.map(&:id)
          )
            .where("created_at::date = ?", today)
            .pluck(:object_id)
            .to_set
          subscriptions.filter { |subscription| subscription_ids_already_alerted.exclude?(subscription.id) }
            .each do |subscription|
              SendWebhookJob.perform_later("subscription.termination_alert", subscription)
            end
        end
    end

    private

    def sent_at_dates(now)
      # NOTE: The alert will be sent 15 and 45 days before the subscription is terminated by default.
      #       You can override the default by setting below env var.
      #       E.g. LAGO_SUBSCRIPTION_TERMINATION_ALERT_SENT_AT_DAYS=1,15,45 will cause it
      #       to be sent at 1, 15, 45 days before subscription terminates, respectively.
      sent_at_days_config = ENV.fetch("LAGO_SUBSCRIPTION_TERMINATION_ALERT_SENT_AT_DAYS", "15,45")
      sent_at_days_config.split(",").map { |day_string| (now + day_string.to_i.days).to_date }
    end
  end
end
