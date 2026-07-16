# frozen_string_literal: true

module UsageMonitoring
  class ProcessAlertService < BaseService
    Result = BaseResult[:alert]

    def initialize(alert:, current_metrics:, alertable:)
      @alert = alert
      @alertable = alertable
      @current_metrics = current_metrics
      super
    end

    def call
      now = Time.current
      current = alert.find_value(current_metrics)

      # NOTE: If the alert is set for a billable metric which is not part of any charges of the plan
      return result if current.nil?

      crossed_threshold_values = alert.find_thresholds_crossed(current)

      ActiveRecord::Base.transaction do
        if crossed_threshold_values.present?
          triggered_alert = TriggeredAlert.create!(
            alert:,
            organization: alert.organization,
            subscription:,
            wallet:,
            current_value: current,
            previous_value: alert.previous_value,
            crossed_thresholds: alert.formatted_crossed_thresholds(crossed_threshold_values),
            triggered_at: now
          )

          after_commit { SendWebhookJob.perform_later("alert.triggered", triggered_alert) }
        end

        alert.previous_value = current
        alert.last_processed_at = now
        alert.save!
      end

      result.alert = alert
      result
    end

    private

    attr_reader :alert, :alertable, :current_metrics

    def subscription
      alertable if alertable.is_a?(Subscription)
    end

    def wallet
      alertable if alertable.is_a?(Wallet)
    end
  end
end
