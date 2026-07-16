# frozen_string_literal: true

module UsageMonitoring
  module Alerts
    class CreateBatchService < BaseService
      Result = BaseResult[:alerts, :errors]

      def initialize(organization:, alertable:, alerts_params:)
        @organization = organization
        @alertable = alertable
        @alerts_params = alerts_params
        super
      end

      def call
        return result.not_found_failure!(resource: "organization") unless organization
        return result.not_found_failure!(resource: "alertable") unless alertable

        if alerts_params.blank?
          return result.single_validation_failure!(error_code: "no_alerts", field: :alerts)
        end

        result.alerts = []
        result.errors = {}

        ActiveRecord::Base.transaction do
          alerts_params.each_with_index do |alert_params, index|
            ActiveRecord::Base.transaction(requires_new: true) do
              create_result = CreateAlertService.call(
                organization:,
                alertable:,
                params: billable_metric_params(alert_params.to_h)
              )

              if create_result.success?
                result.alerts << create_result.alert
              else
                error_details = {}
                error_details[:params] = alert_params
                error_details[:errors] = create_result.error&.message
                result.errors[index] = error_details
                raise ActiveRecord::Rollback
              end
            end
          end

          raise ActiveRecord::Rollback if result.errors.any?
        end

        if result.errors.any?
          result.alerts = []
          return result.validation_failure!(errors: result.errors)
        end

        result
      end

      private

      attr_reader :organization, :alertable, :alerts_params

      def preloaded_billable_metrics
        @preloaded_billable_metrics ||= begin
          codes = alerts_params.filter_map { |p| p[:billable_metric_code] }.uniq
          ids = alerts_params.filter_map { |p| p[:billable_metric_id] }.uniq

          metrics = organization.billable_metrics.where(code: codes).or(
            organization.billable_metrics.where(id: ids)
          )

          {
            by_code: metrics.index_by(&:code),
            by_id: metrics.index_by { |m| m.id.to_s }
          }
        end
      end

      def billable_metric_params(alert_params)
        if alert_params[:billable_metric_code]
          bm = preloaded_billable_metrics.fetch(:by_code).fetch(alert_params[:billable_metric_code], nil)
          alert_params[:billable_metric] = bm if bm
        elsif alert_params[:billable_metric_id]
          bm = preloaded_billable_metrics.fetch(:by_id).fetch(alert_params[:billable_metric_id].to_s, nil)
          alert_params[:billable_metric] = bm if bm
        end

        alert_params
      end
    end
  end
end
