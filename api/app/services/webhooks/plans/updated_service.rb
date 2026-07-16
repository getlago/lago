# frozen_string_literal: true

module Webhooks
  module Plans
    class UpdatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PlanSerializer.new(
          object,
          root_name: "plan",
          includes: %i[charges usage_thresholds taxes minimum_commitment entitlements]
        )
      end

      def webhook_type
        "plan.updated"
      end

      def object_type
        "plan"
      end
    end
  end
end
