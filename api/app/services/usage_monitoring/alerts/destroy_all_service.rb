# frozen_string_literal: true

module UsageMonitoring
  module Alerts
    class DestroyAllService < BaseService
      Result = BaseResult[:alerts]

      def initialize(alertable:)
        @alertable = alertable
        super
      end

      def call
        return result.not_found_failure!(resource: "alertable") unless alertable

        alert_ids = alertable.alerts.ids

        ActiveRecord::Base.transaction do
          AlertThreshold.where(usage_monitoring_alert_id: alert_ids).delete_all
          Alert.where(id: alert_ids).update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
        end

        result
      end

      private

      attr_reader :organization, :alertable
    end
  end
end
