# frozen_string_literal: true

module Webhooks
  module Plans
    class DeletedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PlanSerializer.new(
          object,
          root_name: "plan",
          includes: %i[charges usage_thresholds taxes minimum_commitment]
        )
      end

      def webhook_type
        "plan.deleted"
      end

      def object_type
        "plan"
      end
    end
  end
end
