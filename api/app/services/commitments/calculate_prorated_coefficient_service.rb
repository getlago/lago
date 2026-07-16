# frozen_string_literal: true

module Commitments
  class CalculateProratedCoefficientService < BaseService
    def initialize(commitment:, invoice_subscription:)
      @commitment = commitment
      @invoice_subscription = invoice_subscription

      super
    end

    def proration_coefficient
      result.proration_coefficient = calculate_proration_coefficient
      result
    end

    def dates_service
      @dates_service ||= Commitments::DatesService.new_instance(commitment:, invoice_subscription:).call
    end

    private

    attr_reader :commitment, :invoice_subscription

    delegate :subscription, to: :invoice_subscription

    def calculate_proration_coefficient
      invoices_service = Commitments::FetchInvoicesService.new_instance(commitment:, invoice_subscription:)
      invoices_result = invoices_service.call

      all_invoice_subscriptions = subscription
        .invoice_subscriptions
        .where(invoice_id: invoices_result.invoices.ids)
        .where("from_datetime >= ?", dates_service.previous_beginning_of_period)
        .order(
          Arel.sql(
            ActiveRecord::Base.sanitize_sql_for_conditions(
              "COALESCE(invoice_subscriptions.to_datetime, invoice_subscriptions.timestamp) ASC"
            )
          )
        )

      days = Utils::Datetime.date_diff_with_timezone(
        all_invoice_subscriptions.first.from_datetime,
        subscription.terminated? ? subscription.terminated_at : invoice_subscription.to_datetime,
        subscription.customer.applicable_timezone
      )

      days_total = Utils::Datetime.date_diff_with_timezone(
        dates_service.previous_beginning_of_period,
        dates_service.end_of_period,
        subscription.customer.applicable_timezone
      )

      days / days_total.to_f
    end
  end
end
