# frozen_string_literal: true

module Invoices
  class CreateAdvanceChargesInvoiceSubscriptionService < BaseService
    Result = BaseResult

    def initialize(invoice:, timestamp:, subscriptions_with_fees:, all_subscriptions:)
      @invoice = invoice
      @timestamp = timestamp
      @subscriptions_with_fees = subscriptions_with_fees
      @all_subscriptions = all_subscriptions

      super
    end

    # Since the `advance_charges` invoice only have charges by design,
    # we apply the `charges_(from|to)_date for both charges and subscriptions period
    # See https://github.com/getlago/lago-api/pull/3327 for details
    def call
      latest_subscription = all_subscriptions.max_by(&:started_at)
      boundaries = calculate_boundaries(latest_subscription)

      subscriptions_with_fees.each do |subscription|
        invoice.invoice_subscriptions << InvoiceSubscription.create!(
          organization: subscription.organization,
          invoice:,
          subscription:,
          timestamp:,
          from_datetime: boundaries[:from],
          to_datetime: boundaries[:to],
          charges_from_datetime: boundaries[:from],
          charges_to_datetime: boundaries[:to],
          recurring: false,
          invoicing_reason: :in_advance_charge_periodic
        )
      end

      result
    end

    private

    attr_reader :invoice, :timestamp, :subscriptions_with_fees, :all_subscriptions

    def calculate_boundaries(subscription)
      date_service = Subscriptions::DatesService.new_instance(subscription, timestamp, current_usage: false)

      {
        from: date_service.charges_from_datetime,
        to: date_service.charges_to_datetime
      }
    end
  end
end
