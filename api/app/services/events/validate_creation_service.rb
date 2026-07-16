# frozen_string_literal: true

module Events
  class ValidateCreationService < BaseService
    Result = BaseResult

    def initialize(organization:, event_params:, customer:, subscriptions: [])
      @organization = organization
      @event_params = event_params
      @customer = customer
      @subscriptions = subscriptions

      super
    end

    def call
      return missing_subscription_error if event_params[:external_subscription_id].blank?
      return missing_subscription_error if subscriptions.empty?

      if subscriptions.pluck(:external_id).exclude?(event_params[:external_subscription_id])
        return missing_subscription_error
      end

      return invalid_timestamp_error unless valid_timestamp?
      return transaction_id_error unless valid_transaction_id?
      return invalid_code_error unless valid_code?
      return invalid_properties_error unless valid_properties?

      result
    end

    private

    attr_reader :organization, :event_params, :customer, :subscriptions

    def valid_timestamp?
      return true if event_params[:timestamp].blank?

      # timestamp is a number of seconds
      valid_number?(event_params[:timestamp])
    end

    def valid_transaction_id?
      return false if event_params[:transaction_id].blank?

      !Event.where(
        organization_id: organization.id,
        transaction_id: event_params[:transaction_id],
        external_subscription_id: subscriptions.first.external_id
      ).exists?
    end

    def valid_code?
      billable_metric.present?
    end

    # This validation checks only field_name value since it is important for aggregation DB query integrity.
    # Other checks are performed later and presented in debugger
    def valid_properties?
      return true unless billable_metric.max_agg? || billable_metric.sum_agg? || billable_metric.latest_agg?

      valid_number?((event_params[:properties] || {})[billable_metric.field_name.to_sym])
    end

    def valid_number?(value)
      true if value.nil? || Float(value)
    rescue ArgumentError
      false
    end

    def missing_subscription_error
      result.not_found_failure!(resource: "subscription")
    end

    def transaction_id_error
      result.validation_failure!(errors: {transaction_id: ["value_is_missing_or_already_exists"]})
    end

    def invalid_code_error
      result.not_found_failure!(resource: "billable_metric")
    end

    def invalid_properties_error
      result.validation_failure!(errors: {properties: ["value_is_not_valid_number"]})
    end

    def invalid_timestamp_error
      result.validation_failure!(errors: {timestamp: ["invalid_format"]})
    end

    def billable_metric
      @billable_metric ||= organization.billable_metrics.find_by(code: event_params[:code])
    end
  end
end
