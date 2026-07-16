# frozen_string_literal: true

module UsageMonitoring
  class UpdateAlertService < BaseService
    include ::UsageMonitoring::Concerns::CreateOrUpdateConcern

    Result = BaseResult[:alert]

    def initialize(alert:, params:)
      @alert = alert
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "alert") unless alert

      if params.has_key?(:thresholds) && params[:thresholds].size > AlertThreshold::SOFT_LIMIT
        return result.single_validation_failure!(field: :thresholds, error_code: "too_many_thresholds")
      end

      if params[:thresholds].present?
        if duplicate_threshold_values?(params[:thresholds])
          return result.single_validation_failure!(field: :thresholds, error_code: "duplicate_threshold_values")
        end

        if !all_threshold_values_present?(params[:thresholds])
          return result.single_validation_failure!(field: "thresholds:value", error_code: "value_is_mandatory")
        end

        if !all_threshold_values_numeric?(params[:thresholds])
          return result.single_validation_failure!(field: "thresholds:value", error_code: "value_is_invalid")
        end

        if !all_recurring_threshold_values_positive?(params[:thresholds])
          return result.single_validation_failure!(field: "thresholds:value", error_code: "recurring_value_is_negative")
        end
      end

      result.alert = alert

      billable_metric = find_billable_metric_from_params!
      return result unless result.success?

      ActiveRecord::Base.transaction do
        alert.name = params[:name] if params.key?(:name)
        alert.code = params[:code] if params.key?(:code)
        alert.billable_metric = billable_metric if billable_metric
        alert.save!

        if params[:thresholds].present?
          alert.thresholds.delete_all
          alert.thresholds.create!(prepare_thresholds(params[:thresholds], alert.organization_id))
        end
      end

      track_subscription_activity if alert.subscription_external_id?
      process_wallet_alerts if alert.wallet_id?

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?("idx_alerts_code_unique_per_subscription")
        result.single_validation_failure!(field: :code, error_code: "value_already_exist")
      else
        # Only one alert per [alert_type, billable_metric] pair is allowed.
        result.single_validation_failure!(field: :base, error_code: "alert_already_exists")
      end
    end

    private

    attr_reader :alert, :params
    delegate :organization, to: :alert

    def track_subscription_activity
      return unless alert.subscription_external_id?
      active_subscription = organization.subscriptions.active
        .find_by(external_id: alert.subscription_external_id)
      return unless active_subscription
      return unless License.premium?

      UsageMonitoring::SubscriptionActivity.insert_all( # rubocop:disable Rails/SkipsModelValidations
        [{organization_id: organization.id, subscription_id: active_subscription.id}],
        unique_by: :idx_subscription_unique
      )
    end

    def process_wallet_alerts
      return unless alert.wallet_id?
      return unless License.premium?
      return unless alert.wallet&.active?

      UsageMonitoring::ProcessWalletAlertsJob.perform_later(alert.wallet)
    end
  end
end
