# frozen_string_literal: true

module V1
  class ApplicableUsageThresholdSerializer < ModelSerializer
    def serialize
      {
        threshold_display_name: model.threshold_display_name,
        amount_cents: model.amount_cents,
        recurring: model.recurring
      }
    end
  end
end
