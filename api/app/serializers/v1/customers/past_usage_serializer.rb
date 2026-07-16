# frozen_string_literal: true

module V1
  module Customers
    class PastUsageSerializer < ModelSerializer
      def serialize
        payload = {
          from_datetime: invoice_subscription.charges_from_datetime.iso8601,
          to_datetime: invoice_subscription.charges_to_datetime.iso8601,
          issuing_date: invoice.issuing_date.iso8601,
          currency: invoice.currency,
          amount_cents: invoice.fees_amount_cents,
          total_amount_cents: invoice.fees_amount_cents + taxes_amount_cents,
          taxes_amount_cents:,
          lago_invoice_id: invoice.id
        }

        payload.merge!(charges_usage) if include?(:charges_usage)
        payload
      end

      private

      delegate :invoice_subscription, :fees, to: :model
      delegate :invoice, to: :invoice_subscription

      def taxes_amount_cents
        @taxes_amount_cents ||= invoice.fees.sum(:taxes_amount_cents)
      end

      def charges_usage
        {
          charges_usage: ::V1::Customers::ChargeUsageSerializer.new(
            fees,
            root_name: "past_usage"
          ).serialize
        }
      end
    end
  end
end
