# frozen_string_literal: true

module EInvoices
  module Payments
    module Common
      delegate :payment_receipt, to: :payment

      def notes
        ["Receipt for payment of #{payment.amount_currency} #{payment.amount} received via #{payment_mode} for invoice #{invoice_numbers}"]
      end

      def credits_and_payments(&block)
        case payment.payment_type
        when Payment::PAYMENT_TYPES[:manual]
          yield EInvoices::BaseSerializer::STANDARD_PAYMENT, Money.new(payment.amount_cents)
        when Payment::PAYMENT_TYPES[:provider]
          yield EInvoices::BaseSerializer::CREDIT_CARD_PAYMENT, Money.new(payment.amount_cents)
        end
      end

      private

      def invoice_numbers
        payment.invoices.pluck(:number).to_sentence
      end

      def payment_mode
        payment.payment_type_manual? ? "Manual" : payment.payment_provider_type
      end
    end
  end
end
