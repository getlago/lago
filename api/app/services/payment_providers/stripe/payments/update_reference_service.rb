# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Payments
      class UpdateReferenceService < BaseService
        Result = BaseResult[:payment]

        def initialize(payment:)
          @payment = payment
          super
        end

        def call
          result.payment = payment
          return result if payment.provider_payment_id.blank?
          return result unless payment.payable.is_a?(Invoice)
          return result if payment.payable.number.blank?

          ::Stripe::PaymentIntent.update(
            payment.provider_payment_id,
            {
              description: invoice.number,
              metadata: {lago_invoice_number: invoice.number}
            },
            {api_key: payment.payment_provider.secret_key}
          )

          result
        rescue ::Stripe::StripeError => e
          # Best-effort. The invoice has already been finalized and the
          # subscription has already activated; updating the PSP-side
          # reference is presentation polish, not correctness. Log a warning
          # and return success so the caller never blocks on this.
          Rails.logger.warn(
            "PaymentProviders::Stripe::Payments::UpdateReferenceService: " \
            "failed to update Stripe PaymentIntent #{payment.provider_payment_id} " \
            "for payment #{payment.id}: #{e.message}"
          )
          result
        end

        private

        attr_reader :payment

        def invoice
          @invoice ||= payment.payable
        end
      end
    end
  end
end
