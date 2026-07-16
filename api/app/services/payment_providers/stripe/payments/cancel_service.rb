# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Payments
      class CancelService < BaseService
        Result = BaseResult[:payment]

        def initialize(payment:)
          @payment = payment
          super
        end

        def call
          stripe_result = ::Stripe::PaymentIntent.cancel(
            payment.provider_payment_id,
            {cancellation_reason: :abandoned},
            {api_key: payment.payment_provider.secret_key}
          )

          payment.status = stripe_result.status
          payment.payable_payment_status = payment.payment_provider.determine_payment_status(payment.status)
          payment.save!

          result.payment = payment
          result
        rescue ::Stripe::InvalidRequestError => e
          # Best-effort cancel only for the "intent in a non-cancelable state"
          # case (succeeded, processing, already canceled, etc.). Log and treat
          # as a successful no-op — the caller (timeout/expiration flow) should
          # not block on PSP-side cleanup. The Payment record is left
          # untouched; the webhook for the prior state transition will land its
          # true state.
          #
          # Other InvalidRequestError codes (bad params, missing resource,
          # idempotency conflicts, etc.) propagate so the caller can retry or
          # surface the failure.
          raise unless e.code == "payment_intent_unexpected_state"

          Rails.logger.info("Stripe payment intent not cancelable for payment #{payment.id}: #{e.message}")
          result
        end

        private

        attr_reader :payment
      end
    end
  end
end
