# frozen_string_literal: true

module UsageMonitoring
  class CreateAlertService < BaseService
    include ::UsageMonitoring::Concerns::CreateOrUpdateConcern

    Result = BaseResult[:alert]

    def initialize(organization:, alertable:, params:)
      @organization = organization
      @alertable = alertable
      @params = params
      super
    end

    def call
      if params[:alert_type].in?(%w[lifetime_usage_amount]) && !organization.using_lifetime_usage?
        return result.single_validation_failure!(field: :alert_type, error_code: "feature_not_available")
      end

      if params[:alert_type].in?(%w[billable_metric_lifetime_usage_units]) && !organization.granular_lifetime_usage_enabled?
        return result.single_validation_failure!(field: :alert_type, error_code: "feature_not_available")
      end

      if params[:alert_type].blank?
        return result.validation_failure!(errors: {alert_type: %w[value_is_mandatory value_is_invalid]})
      end

      unless Alert::STI_MAPPING.key?(params[:alert_type])
        return result.single_validation_failure!(field: :alert_type, error_code: "invalid_type")
      end

      if alertable.is_a?(Wallet) && !Alert::WALLET_TYPES.include?(params[:alert_type])
        return result.single_validation_failure!(field: :alert_type, error_code: "invalid_type")
      end

      if alertable.is_a?(Subscription) && Alert::WALLET_TYPES.include?(params[:alert_type])
        return result.single_validation_failure!(field: :alert_type, error_code: "invalid_type")
      end

      if params[:thresholds].blank?
        return result.single_validation_failure!(field: :thresholds, error_code: "value_is_mandatory")
      end

      if params[:thresholds].size > AlertThreshold::SOFT_LIMIT
        return result.single_validation_failure!(field: :thresholds, error_code: "too_many_thresholds")
      end

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

      billable_metric = find_billable_metric_from_params!
      return result unless result.success?

      ActiveRecord::Base.transaction do
        alert = Alert.new(
          organization:,
          subscription_external_id: subscription&.external_id,
          wallet: wallet,
          billable_metric:,
          alert_type: params[:alert_type].to_s,
          name: params[:name],
          code: params[:code],
          direction: direction_for_alert
        )

        alertable.with_lock do
          # Lock alertable to prevent any changes to it and avoid it becoming stale
          # as we set previous_value to the alertable metric when the alert
          # direction is :decreasing
          alert.previous_value = alert.find_value(alertable) if alert.decreasing?
          alert.save!
        end

        alert.thresholds.create!(prepare_thresholds(params[:thresholds], organization.id))

        result.alert = alert
      end

      track_subscription_activity if subscription
      process_wallet_alerts if wallet

      result
    rescue KeyError
      result.single_validation_failure!(field: :alert_type, error_code: "invalid_type")
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?("idx_alerts_code_unique_per_subscription") || e.message.include?("idx_alerts_code_unique_per_wallet")
        result.single_validation_failure!(field: :code, error_code: "value_already_exist")
      else
        # Only one alert per [alert_type, billable_metric] pair is allowed.
        result.single_validation_failure!(field: :base, error_code: "alert_already_exists")
      end
    end

    private

    attr_reader :organization, :alertable, :params

    def subscription
      alertable if alertable.is_a?(Subscription)
    end

    def wallet
      alertable if alertable.is_a?(Wallet)
    end

    def direction_for_alert
      Alert::WALLET_TYPES.include?(params[:alert_type]) ? "decreasing" : "increasing"
    end

    def track_subscription_activity
      return unless License.premium?
      return unless subscription.active?

      UsageMonitoring::SubscriptionActivity.insert_all( # rubocop:disable Rails/SkipsModelValidations
        [{organization_id: organization.id, subscription_id: subscription.id}],
        unique_by: :idx_subscription_unique
      )
    end

    def process_wallet_alerts
      return unless License.premium?
      return unless wallet.active?

      UsageMonitoring::ProcessWalletAlertsJob.perform_later(wallet)
    end
  end
end
