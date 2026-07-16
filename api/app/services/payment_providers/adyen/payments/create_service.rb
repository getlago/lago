# frozen_string_literal: true

module PaymentProviders
  module Adyen
    module Payments
      class CreateService < BaseService
        def initialize(payment:, reference:, metadata:)
          @payment = payment
          @reference = reference
          @metadata = metadata
          @invoice = payment.payable
          @provider_customer = payment.payment_provider_customer

          super
        end

        def call
          result.payment = payment

          adyen_result = create_adyen_payment

          if adyen_result.status > 400
            return prepare_failed_result(::Adyen::AdyenError.new(
              nil, nil, adyen_result.response["message"], adyen_result.response["errorType"]
            ))
          end

          payment.provider_payment_id = adyen_result.response["pspReference"]
          payment.status = adyen_result.response["resultCode"]
          payment.payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
          payment.save!

          result.payment = payment
          result
        rescue ::Adyen::AuthenticationError, ::Adyen::ValidationError => e
          prepare_failed_result(e)
        rescue ::Adyen::AdyenError => e
          prepare_failed_result(e, reraise: true)
        rescue Faraday::ConnectionFailed => e
          # Allow auto-retry with idempotency key
          raise Invoices::Payments::ConnectionError, e
        end

        private

        attr_reader :payment, :reference, :metadata, :invoice, :provider_customer

        delegate :payment_provider, :customer, to: :provider_customer

        def client
          @client ||= ::Adyen::Client.new(
            api_key: payment_provider.api_key,
            env: payment_provider.environment,
            live_url_prefix: payment_provider.live_prefix
          )
        end

        def success_redirect_url
          payment_provider.success_redirect_url.presence || ::PaymentProviders::AdyenProvider::SUCCESS_REDIRECT_URL
        end

        def update_payment_method_id
          result = client.checkout.payments_api.payment_methods(
            Lago::Adyen::Params.new(payment_method_params).to_h
          ).response

          payment_method_id = result["storedPaymentMethods"]&.first&.dig("id")

          if payment_method_id
            provider_customer.update!(payment_method_id:)
          end
        end

        def create_adyen_payment
          update_payment_method_id

          client.checkout.payments_api.payments(
            Lago::Adyen::Params.new(payment_params).to_h,
            headers: {"idempotency-key" => "payment-#{payment.id}"}
          )
        end

        def payment_method_params
          {
            merchantAccount: payment_provider.merchant_account,
            shopperReference: provider_customer.provider_customer_id
          }
        end

        def payment_params
          prms = {
            amount: {
              currency: payment.amount_currency.upcase,
              value: payment.amount_cents
            },
            reference: reference,
            paymentMethod: {
              type: "scheme",
              storedPaymentMethodId: payment_method_id
            },
            shopperReference: provider_customer.provider_customer_id,
            merchantAccount: payment_provider.merchant_account,
            shopperInteraction: "ContAuth",
            recurringProcessingModel: "UnscheduledCardOnFile"
          }
          prms[:shopperEmail] = customer.email if customer.email
          prms
        end

        def payment_method_id
          payment.payment_method&.provider_method_id || provider_customer.payment_method_id
        end

        def prepare_failed_result(error, reraise: false)
          result.error_message = error.msg
          result.error_code = error.code
          result.reraise = reraise

          payment.update!(status: :failed, payable_payment_status: :failed)

          result.service_failure!(code: "adyen_error", message: "#{error.code}: #{error.msg}")
        end
      end
    end
  end
end
