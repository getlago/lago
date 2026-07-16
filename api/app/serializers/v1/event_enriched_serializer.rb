# frozen_string_literal: true

module V1
  class EventEnrichedSerializer < ModelSerializer
    def serialize
      {
        transaction_id: model.transaction_id,
        external_subscription_id: model.external_subscription_id,
        code: model.code,
        timestamp: model.timestamp.iso8601(3),
        enriched_at: model.enriched_at&.iso8601(3),
        value: model.value,
        decimal_value: model.decimal_value.to_s,
        precise_total_amount_cents: model.precise_total_amount_cents&.to_s,
        properties: model.properties
      }
    end
  end
end
