# frozen_string_literal: true

module V1
  module Subscriptions
    class ActivationRuleSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          type: model.class.sti_name,
          timeout_hours: model.timeout_hours,
          status: model.status,
          expires_at: model.expires_at&.iso8601,
          created_at: model.created_at.iso8601,
          updated_at: model.updated_at.iso8601
        }
      end
    end
  end
end
