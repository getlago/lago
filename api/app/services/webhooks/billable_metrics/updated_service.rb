# frozen_string_literal: true

module Webhooks
  module BillableMetrics
    class UpdatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::BillableMetricSerializer.new(
          object,
          root_name: "billable_metric"
        )
      end

      def webhook_type
        "billable_metric.updated"
      end

      def object_type
        "billable_metric"
      end
    end
  end
end
