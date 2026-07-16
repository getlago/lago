# frozen_string_literal: true

module V1
  class EventSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        transaction_id: model.transaction_id,
        lago_customer_id: model.customer_id,
        code: model.code,
        timestamp: model.timestamp.iso8601(3),
        precise_total_amount_cents: model.precise_total_amount_cents&.to_s,
        properties: model.properties,
        lago_subscription_id: model.subscription_id,
        external_subscription_id: model.external_subscription_id,
        created_at: model.created_at&.iso8601
      }
    end
  end
end
