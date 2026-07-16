# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class BillFixedChargesDeltaService < BaseService
      Result = BaseResult

      def initialize(subscription:)
        @subscription = subscription
        super
      end

      def call
        return result unless subscription.fixed_charges.pay_in_advance.any?

        delta_event_timestamps.each do |timestamp|
          next if billed_timestamps.include?(timestamp)

          invoice_result = Invoices::CreatePayInAdvanceFixedChargesService.call(
            subscription:,
            timestamp:
          )
          next if invoice_result.success? || tax_error?(invoice_result)

          invoice_result.raise_if_error!
        end

        result
      end

      private

      attr_reader :subscription

      def delta_event_timestamps
        window_begin = subscription.started_at + 1.second

        subscription.fixed_charge_events
          .where(fixed_charge: subscription.fixed_charges.pay_in_advance)
          .where("fixed_charge_events.timestamp > ? AND fixed_charge_events.timestamp <= ?", window_begin, window_end)
          .distinct
          .order(:timestamp)
          .pluck(:timestamp)
          .map(&:to_i)
      end

      def window_end
        first_period_end = Subscriptions::DatesService
          .fixed_charge_pay_in_advance_interval(subscription.started_at.to_i, subscription)
          .fetch(:fixed_charges_to_datetime)

        [Time.current, first_period_end].min
      end

      def billed_timestamps
        @billed_timestamps ||= subscription.invoice_subscriptions
          .where(invoicing_reason: :in_advance_charge)
          .joins(invoice: :fees)
          .where(fees: {fee_type: :fixed_charge})
          .distinct
          .pluck(:timestamp)
          .map(&:to_i)
      end

      def tax_error?(invoice_result)
        return false unless invoice_result.error.is_a?(BaseService::ValidationFailure)

        invoice_result.error.messages&.dig(:tax_error).present?
      end
    end
  end
end
