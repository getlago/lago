# frozen_string_literal: true

require "timecop"

module DailyUsages
  class FillHistoryService < BaseService
    Result = BaseResult[]

    def initialize(subscription:, from_date:, to_date: nil, sandbox: false)
      @subscription = subscription
      @from_date = from_date
      @to_date = to_date
      @sandbox = sandbox

      super
    end

    def call
      previous_daily_usage = nil
      produces_daily_usage = produces_daily_usage_without_events?

      (from..to).each do |date|
        if !sandbox && (existing_daily_usage = subscription.daily_usages.find_by(usage_date: date))
          previous_daily_usage = existing_daily_usage
          next
        end

        datetime = date.in_time_zone(subscription.customer.applicable_timezone).beginning_of_day.utc
        datetime = date.beginning_of_day.utc if datetime < date # Handle last day for timezone with positive offset

        Timecop.thread_safe = true
        time_to_freeze = datetime.in_time_zone(subscription.customer.applicable_timezone).end_of_day

        # Check if events were received for this date
        if event_dates.exclude?(date)
          # NOTE: On first day of a period, recurring metrics should be considered to report usage from
          #       the previous period. Otherwise we can skip them until new events are received
          force_recurring = recurring_charges? && billing_period_first_days.include?(date)
          next if !produces_daily_usage && !force_recurring
        end

        Timecop.freeze(time_to_freeze) do
          usage = Invoices::CustomerUsageService.call(
            customer: subscription.customer,
            subscription: subscription,
            apply_taxes: false,
            with_cache: false,
            max_timestamp: time_to_freeze,
            with_zero_units_filters: false
          ).raise_if_error!.usage
          next if sandbox

          if previous_daily_usage.present? && previous_daily_usage.from_datetime != usage.from_datetime
            # NOTE: A new billing period was started, the diff should contains the complete current usage
            previous_daily_usage = nil
          end

          usage.fees = usage.fees.select(&:non_zero?)

          if usage.fees.any?
            daily_usage = DailyUsage.new(
              organization:,
              customer: subscription.customer,
              subscription:,
              external_subscription_id: subscription.external_id,
              usage: ::V1::Customers::UsageSerializer.new(usage, includes: %i[charges_usage]).serialize,
              from_datetime: usage.from_datetime,
              to_datetime: usage.to_datetime,
              refreshed_at: datetime,
              usage_diff: {},
              usage_date: date
            )

            if date != from
              daily_usage.usage_diff = DailyUsages::ComputeDiffService
                .call(daily_usage:, previous_daily_usage:)
                .raise_if_error!
                .usage_diff
            end

            daily_usage.save!

            previous_daily_usage = daily_usage
          end
        end
      end

      if subscription.terminated?
        invoice = subscription.invoices
          .joins(:invoice_subscriptions)
          .where(invoice_subscriptions: {invoicing_reason: "subscription_terminating"})
          .first

        if invoice.present?
          DailyUsages::FillFromInvoiceJob.perform_later(invoice:, subscriptions: [subscription])
        end
      end

      result
    end

    attr_reader :subscription, :from_date, :to_date, :sandbox
    delegate :organization, to: :subscription

    def from
      @from ||= [
        subscription.started_at.in_time_zone(timezone).to_date,
        from_date
      ].max
    end

    def to
      @to ||= if subscription.terminated?
        subscription.terminated_at.in_time_zone(timezone).to_date
      else
        to_date || Time.zone.yesterday.in_time_zone(timezone).to_date
      end
    end

    def timezone
      @timezone ||= subscription.customer.applicable_timezone
    end

    # NOTE: Returns the set of dates (in the customer timezone) that received at least one event
    #       over the whole [from..to] range. Computed in a single query to avoid a per-day lookup.
    def event_dates
      @event_dates ||= begin
        range = from.in_time_zone(timezone).beginning_of_day..to.in_time_zone(timezone).end_of_day

        dates = if ENV["LAGO_CLICKHOUSE_ENABLED"].present? && subscription.organization.clickhouse_events_store?
          quoted_timezone = Clickhouse::BaseRecord.connection.quote(timezone)

          Clickhouse::EventsEnriched
            .where(organization_id: subscription.organization_id)
            .where(external_subscription_id: subscription.external_id)
            .where(timestamp: range)
            .distinct
            .pluck(Arel.sql("toDate(timestamp, #{quoted_timezone})"))
        else
          quoted_timezone = Event.connection.quote(timezone)

          Event
            .where(organization_id: subscription.organization_id)
            .where(external_subscription_id: subscription.external_id)
            .where(timestamp: range)
            .distinct
            .pluck(Arel.sql("DATE((events.timestamp)::timestamptz AT TIME ZONE #{quoted_timezone})"))
        end

        dates.map { |date| date.is_a?(Date) ? date : Date.parse(date.to_s) }.to_set
      end
    end

    # NOTE: Usage on prorated or weighted sum charges evolves daily even without events.
    #       These require a forced daily usage snapshot on every day of the range.
    def produces_daily_usage_without_events?
      Charge.joins(:billable_metric)
        .where(plan_id: subscription.plan_id)
        .where(
          "charges.prorated = ? OR billable_metrics.aggregation_type = ?",
          true,
          BillableMetric.aggregation_types[:weighted_sum_agg]
        )
        .exists?
    end

    def recurring_charges?
      return @recurring_charges if defined?(@recurring_charges)

      @recurring_charges = Charge.joins(:billable_metric)
        .where(plan_id: subscription.plan_id)
        .where(billable_metrics: {recurring: true})
        .exists?
    end

    # NOTE: Returns the set of dates (in the customer timezone) that are the first day of a billing
    #       period within the [from..to] range.
    def billing_period_first_days
      @billing_period_first_days ||= (from..to).each_with_object(Set.new) do |date, set|
        date_service = Subscriptions::DatesService.new_instance(
          subscription,
          date.in_time_zone(timezone).end_of_day,
          current_usage: true
        )
        set << date_service.from_datetime.in_time_zone(timezone).to_date
      end
    end
  end
end
