# frozen_string_literal: true

module PaymentProviders
  class CancelPaymentService < BaseService
    Result = BaseResult[:payment]

    def initialize(payment:)
      @payment = payment
      super
    end

    def call
      result.payment = payment

      return result if payment.payment_provider.blank?
      return result if payment.provider_payment_id.blank?
      return result if payment.succeeded?

      case payment.payment_provider.type
      when "PaymentProviders::StripeProvider"
        PaymentProviders::Stripe::Payments::CancelService.call!(payment:)
      when "PaymentProviders::AdyenProvider"
        PaymentProviders::Adyen::Payments::CancelService.call!(payment:)
      when "PaymentProviders::GocardlessProvider"
        PaymentProviders::Gocardless::Payments::CancelService.call!(payment:)
      else
        # Cashfree, Flutterwave, MoneyHash, and any future provider without a
        # dedicated cancel service: nothing to do here. The eventual webhook
        # (or reconciliation) is the lifecycle authority for the Payment.
        Rails.logger.info(
          "PaymentProviders::CancelPaymentService: PSP cancel not supported for " \
          "#{payment.payment_provider.type} (payment #{payment.id}); skipping"
        )
      end

      result
    end

    private

    attr_reader :payment
  end
end
