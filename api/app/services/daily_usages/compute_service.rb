# frozen_string_literal: true

module DailyUsages
  class ComputeService < BaseService
    Result = BaseResult[:daily_usage]

    def initialize(subscription:, timestamp:)
      @subscription = subscription
      @timestamp = timestamp
      super
    end

    def call
      if subscription_billing_day?
        # Usage on billing day will be computed using the periodic invoice as we cannot rely on the caching mechanism
        return result
      end

      if existing_daily_usage.present?
        result.daily_usage = existing_daily_usage
        return result
      end

      current_usage.fees = current_usage.fees.select(&:non_zero?)

      if current_usage.fees.any?
        daily_usage = DailyUsage.new(
          organization: subscription.organization,
          customer: subscription.customer,
          subscription:,
          external_subscription_id: subscription.external_id,
          usage: ::V1::Customers::UsageSerializer.new(current_usage, includes: %i[charges_usage]).serialize,
          from_datetime: current_usage.from_datetime,
          to_datetime: current_usage.to_datetime,
          refreshed_at: timestamp,
          usage_date:
        )

        daily_usage.usage_diff = diff_usage(daily_usage)
        daily_usage.save!

        result.daily_usage = daily_usage
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :subscription, :timestamp

    delegate :customer, to: :subscription

    def current_usage
      return @current_usage if defined?(@current_usage)
      with_cache = true

      # Subscription has been terminated before the initial enqueue of the the job
      # In that case, we cannot rely on the cache as it will not be relevant anymore
      with_cache = false if subscription.terminated? && subscription.terminated_at > timestamp

      @current_usage = Invoices::CustomerUsageService.call(
        customer: subscription.customer,
        subscription: subscription,
        apply_taxes: false,
        with_cache:,
        # Force the timestamp, to allow computing usage if terminated subscription with the right boundaries
        timestamp: with_cache ? Time.current : timestamp
      ).raise_if_error!.usage
    end

    def existing_daily_usage
      @existing_daily_usage ||= DailyUsage.usage_date_in_timezone(usage_date)
        .find_by(subscription_id: subscription.id)
    end

    def diff_usage(daily_usage)
      DailyUsages::ComputeDiffService.call!(daily_usage:).usage_diff
    end

    def subscription_billing_day?
      previous_billing_date_in_timezone = Subscriptions::DatesService
        .new_instance(subscription, timestamp, current_usage: true)
        .previous_beginning_of_period
        .in_time_zone(customer.applicable_timezone)
        .to_date

      date_in_timezone == previous_billing_date_in_timezone
    end

    def date_in_timezone
      @date_in_timezone ||= timestamp.in_time_zone(customer.applicable_timezone).to_date
    end

    def usage_date
      @usage_date ||= date_in_timezone - 1.day
    end
  end
end
