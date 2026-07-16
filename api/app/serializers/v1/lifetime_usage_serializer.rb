# frozen_string_literal: true

module V1
  class LifetimeUsageSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        lago_subscription_id: model.subscription_id,
        external_subscription_id: model.subscription.external_id,
        external_historical_usage_amount_cents: model.historical_usage_amount_cents,
        invoiced_usage_amount_cents: model.invoiced_usage_amount_cents,
        current_usage_amount_cents: model.current_usage_amount_cents,
        from_datetime: model.subscription.subscription_at&.iso8601,
        to_datetime: Time.current.iso8601
      }

      payload.merge!(usage_thresholds) if include?(:usage_thresholds) && model.subscription.has_progressive_billing?
      payload
    end

    private

    def usage_thresholds
      result = LifetimeUsages::UsageThresholdsCompletionService.call(lifetime_usage: model).raise_if_error!
      {usage_thresholds: result.usage_thresholds.map { |r| r.slice(:amount_cents, :completion_ratio, :reached_at) }}
    end
  end
end
