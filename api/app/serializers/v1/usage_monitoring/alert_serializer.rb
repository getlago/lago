# frozen_string_literal: true

module V1
  module UsageMonitoring
    class AlertSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          lago_organization_id: model.organization_id,
          subscription_external_id: model.subscription_external_id, # DEPRECATED
          external_subscription_id: model.subscription_external_id,
          lago_wallet_id: model.wallet_id,
          wallet_code: model.wallet&.code,
          alert_type: model.alert_type,
          code: model.code,
          name: model.name,
          direction: model.direction,
          previous_value: model.previous_value,
          last_processed_at: model.last_processed_at&.iso8601,
          thresholds: formatted_thresholds,
          created_at: model.created_at&.iso8601,
          billable_metric: model.billable_metric_id ? billable_metric : nil
        }
      end

      private

      def formatted_thresholds
        model.thresholds.map do |threshold|
          {
            code: threshold.code,
            value: threshold.value,
            recurring: threshold.recurring
          }
        end
      end

      def billable_metric
        ::V1::BillableMetricSerializer.new(model.billable_metric).serialize
      end
    end
  end
end
