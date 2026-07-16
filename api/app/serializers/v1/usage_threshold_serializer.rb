# frozen_string_literal: true

module V1
  class UsageThresholdSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        threshold_display_name: model.threshold_display_name,
        amount_cents: model.amount_cents,
        recurring: model.recurring,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601
      }
    end
  end
end
