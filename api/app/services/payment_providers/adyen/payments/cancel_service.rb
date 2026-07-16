# frozen_string_literal: true

module PaymentProviders
  module Adyen
    module Payments
      class CancelService < BaseService
        Result = BaseResult[:payment]

        def initialize(payment:)
          @payment = payment
          super
        end

        def call
          adyen_result = client.checkout.modifications_api.cancel_authorised_payment_by_psp_reference(
            {merchantAccount: payment.payment_provider.merchant_account},
            payment.provider_payment_id,
            headers: {"Idempotency-Key" => "payment-#{payment.id}"}
          )

          if adyen_result.status == 422
            # Best-effort cancel only for the "modification cannot apply to
            # current state" case. Adyen returns 422 for validation/state
            # errors — most commonly "modification not allowed on transaction
            # status" when the payment is already captured/cancelled or
            # otherwise outside the cancellable lifecycle window. Log and
            # treat as a successful no-op so the caller (timeout/expiration
            # flow) does not block on PSP-side cleanup.
            Rails.logger.info(
              "Adyen payment not cancelable for payment #{payment.id}: " \
              "status=#{adyen_result.status} message=#{adyen_result.response["message"]}"
            )
            result.payment = payment
            return result
          end

          if adyen_result.status >= 400
            raise ::Adyen::AdyenError.new(
              nil, nil, adyen_result.response["message"], adyen_result.response["errorType"]
            )
          end

          # Adyen's sync cancel response is an acknowledgment ("received"), not
          # a final state — Adyen confirms the actual cancellation
          # asynchronously via the CANCELLATION webhook. The Payment record
          # stays in its prior state until that webhook lands.
          result.payment = payment
          result
        rescue ::Adyen::ValidationError => e
          Rails.logger.info("Adyen payment not cancelable for payment #{payment.id}: #{e.msg}")
          result.payment = payment
          result
        rescue Faraday::ConnectionFailed => e
          raise Invoices::Payments::ConnectionError, e
        end

        private

        attr_reader :payment

        def client
          @client ||= ::Adyen::Client.new(
            api_key: payment.payment_provider.api_key,
            env: payment.payment_provider.environment,
            live_url_prefix: payment.payment_provider.live_prefix
          )
        end
      end
    end
  end
end
