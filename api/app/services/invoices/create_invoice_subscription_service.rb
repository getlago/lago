# frozen_string_literal: true

module Invoices
  class CreateInvoiceSubscriptionService < BaseService
    Result = BaseResult[:invoice_subscriptions]

    def initialize(invoice:, subscriptions:, timestamp:, invoicing_reason:, refresh: false)
      @invoice = invoice
      @subscriptions = subscriptions
      @timestamp = timestamp
      @invoicing_reason = invoicing_reason
      @recurring = invoicing_reason.to_sym == :subscription_periodic
      @refresh = refresh

      super
    end

    def call
      if duplicated_invoices?
        return result.service_failure!(
          code: "duplicated_invoices",
          message: "Invoice subscription already exists with the boundaries"
        )
      end

      result.invoice_subscriptions = []

      impacted_subscriptions.each do |subscription|
        subscription_boundaries = subscriptions_boundaries[subscription.id]
        boundaries = termination_boundaries(subscription, subscription_boundaries)

        result.invoice_subscriptions << InvoiceSubscription.create!(
          organization: subscription.organization,
          invoice:,
          subscription:,
          timestamp: boundaries.timestamp,
          from_datetime: boundaries.from_datetime,
          to_datetime: boundaries.to_datetime,
          charges_from_datetime: boundaries.charges_from_datetime,
          charges_to_datetime: boundaries.charges_to_datetime,
          fixed_charges_from_datetime: boundaries.fixed_charges_from_datetime,
          fixed_charges_to_datetime: boundaries.fixed_charges_to_datetime,
          recurring: invoicing_reason.to_sym == :subscription_periodic,
          invoicing_reason: invoicing_reason_for_subscription(subscription)
        )
      end

      result
    end

    private

    attr_accessor :invoice, :subscriptions, :timestamp, :invoicing_reason, :recurring, :refresh

    def datetime
      @datetime ||= Time.zone.at(timestamp)
    end

    def impacted_subscriptions
      @impacted_subscriptions ||= if refresh
        subscriptions
      elsif recurring
        subscriptions.select(&:active?).uniq(&:id)
      else
        subscriptions.uniq(&:id)
      end
    end

    def duplicated_invoices?
      return false unless recurring

      subscriptions_boundaries.any? do |subscription_id, boundaries|
        subscription = Subscription.includes(:plan).find(subscription_id)

        InvoiceSubscription.matching?(subscription, boundaries)
      end
    end

    def subscriptions_boundaries
      @subscriptions_boundaries ||= impacted_subscriptions.each_with_object({}) do |subscription, boundaries|
        boundaries[subscription.id] = calculate_boundaries(subscription)
      end
    end

    def calculate_boundaries(subscription)
      ds = date_service(subscription)

      BillingPeriodBoundaries.new(
        from_datetime: ds.from_datetime,
        to_datetime: ds.to_datetime,
        charges_from_datetime: ds.charges_from_datetime,
        charges_to_datetime: ds.charges_to_datetime,
        charges_duration: ds.charges_duration_in_days,
        fixed_charges_from_datetime: ds.fixed_charges_from_datetime,
        fixed_charges_to_datetime: ds.fixed_charges_to_datetime,
        fixed_charges_duration: ds.fixed_charges_duration_in_days,
        timestamp: datetime
      )
    end

    def date_service(subscription)
      current_usage = invoicing_reason.to_sym == :progressive_billing
      current_usage ||= subscription.terminated_at?(datetime) && subscription.upgraded?

      Subscriptions::DatesService.new_instance(subscription, datetime, current_usage:)
    end

    # This method calculates boundaries for terminated subscription. If termination is happening on billing date
    # new boundaries will be calculated only if there is no invoice subscription object for previous period.
    # Basically, we will bill regular subscription amount for previous period.
    # If subscription is happening on any other day, method is returning boundaries only for the used dates in
    # current period
    def termination_boundaries(subscription, boundaries)
      return boundaries unless subscription.terminated? && subscription.next_subscription.nil?

      # First we need to ensure that termination date is not started_at date. In that case boundaries are correct
      # and we should bill only one day. If this is not the case we should proceed.
      return boundaries if (datetime - 1.day) < subscription.started_at

      # Date service has various checks for terminated subscriptions. We want to avoid it and fetch boundaries
      # for current usage (current period) but when subscription was active (one day ago)
      duplicate = subscription.dup.tap { |s| s.status = :active }

      dates_service = Subscriptions::DatesService.new_instance(duplicate, datetime - 1.day, current_usage: true)
      return boundaries if datetime < dates_service.charges_to_datetime
      return boundaries unless (datetime - dates_service.charges_to_datetime) < 1.day

      # We should calculate boundaries as if subscription was not terminated
      ds = Subscriptions::DatesService.new_instance(duplicate, datetime, current_usage: false)

      previous_period_boundaries = BillingPeriodBoundaries.new(
        from_datetime: ds.from_datetime,
        to_datetime: ds.to_datetime,
        charges_from_datetime: ds.charges_from_datetime,
        charges_to_datetime: ds.charges_to_datetime,
        fixed_charges_from_datetime: ds.fixed_charges_from_datetime,
        fixed_charges_to_datetime: ds.fixed_charges_to_datetime,
        timestamp: datetime,
        charges_duration: ds.charges_duration_in_days,
        fixed_charges_duration: ds.fixed_charges_duration_in_days
      )

      InvoiceSubscription.matching?(subscription, previous_period_boundaries) ? boundaries : previous_period_boundaries
    end

    def invoicing_reason_for_subscription(subscription)
      # NOTE: upgrading is used as a not persisted reason as it means
      #       one subscription starting and a second one terminating
      return invoicing_reason if invoicing_reason.to_sym != :upgrading
      return :subscription_terminating if subscription.terminated_at?(timestamp)

      :subscription_starting
    end
  end
end
