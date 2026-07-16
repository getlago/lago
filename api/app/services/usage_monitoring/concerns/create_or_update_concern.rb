# frozen_string_literal: true

module UsageMonitoring
  module Concerns
    module CreateOrUpdateConcern
      extend ActiveSupport::Concern

      def find_billable_metric_from_params!
        if params[:billable_metric]
          params[:billable_metric]
        elsif params[:billable_metric_id]
          organization.billable_metrics.find_by!(id: params[:billable_metric_id])
        elsif params[:billable_metric_code]
          organization.billable_metrics.find_by!(code: params[:billable_metric_code])
        end
      rescue ActiveRecord::RecordNotFound
        result.not_found_failure!(resource: "billable_metric")
      end

      def duplicate_threshold_values?(thresholds)
        threshold_keys = thresholds.map { |t| [t[:value], ActiveModel::Type::Boolean.new.cast(t[:recurring]) || false] }
        threshold_keys.size != threshold_keys.uniq.size
      end

      def all_threshold_values_present?(thresholds)
        thresholds.none? { it[:value].nil? }
      end

      def all_threshold_values_numeric?(thresholds)
        thresholds.all? { |t| valid_numeric_value?(t[:value]) }
      end

      def all_recurring_threshold_values_positive?(thresholds)
        thresholds.all? do |t|
          recurring = ActiveModel::Type::Boolean.new.cast(t[:recurring])
          value = ActiveModel::Type::Decimal.new.cast(t[:value])

          !recurring || value.positive?
        end
      end

      def valid_numeric_value?(value)
        case value
        when Numeric
          true
        when String
          return false if value.blank?

          Float(value)
          true
        else
          false
        end
      rescue ArgumentError
        false
      end
    end
  end
end
