# frozen_string_literal: true

module PaymentProviders
  module Moneyhash
    module Payments
      class CreateService < BaseService
        include ::Customers::PaymentProviderFinder

        def initialize(payment:, reference:, metadata:)
          @payment = payment
          @invoice = payment.payable
          @provider_customer = payment.payment_provider_customer

          super
        end

        def call
          result.payment = payment

          moneyhash_result = create_moneyhash_payment

          payment.provider_payment_id = moneyhash_result.dig("data", "id")
          payment.status = moneyhash_result.dig("data", "status") || moneyhash_result.dig("data", "active_transaction", "status") || "PENDING"
          payment.payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
          payment.save!

          result.payment = payment
          result
        end

        private

        attr_reader :payment, :invoice, :provider_customer

        delegate :customer, to: :invoice

        def create_moneyhash_payment
          payment_params = {
            amount: payment.amount_cents.div(100).to_f,
            amount_currency: payment.amount_currency.upcase,
            flow_id: moneyhash_payment_provider.flow_id,
            billing_data: provider_customer.mh_billing_data,
            customer: provider_customer.provider_customer_id,
            webhook_url: moneyhash_payment_provider.webhook_end_point,
            payment_type: "UNSCHEDULED",
            merchant_initiated: true,
            recurring_data: {
              agreement_id: customer.id
            },
            card_token: moneyhash_payment_method_id,
            custom_fields: {
              # plan/subscription
              lago_plan_id: invoice.subscriptions&.first&.plan_id.to_s,
              lago_subscription_external_id: invoice.subscriptions&.first&.external_id.to_s,
              # payable
              lago_payable_id: invoice.id,
              lago_payable_type: invoice.class.name,
              lago_payable_invoice_type: invoice.invoice_type.to_s,
              # mit flag
              lago_mit: true,
              # service
              lago_mh_service: "PaymentProviders::Moneyhash::Payments::CreateService",
              # request
              lago_request: "invoice_automatic_payment"
            }
          }

          payment_params[:custom_fields].merge!(provider_customer.mh_custom_fields)

          headers = {
            "Content-Type" => "application/json",
            "x-Api-Key" => moneyhash_payment_provider.api_key
          }

          response = client.post_with_response(payment_params, headers)
          JSON.parse(response.body)
        rescue LagoHttpClient::HttpError => e
          prepare_failed_result(e, reraise: true)
        end

        def client
          @client || LagoHttpClient::Client.new("#{::PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/payments/intent/")
        end

        def moneyhash_payment_provider
          @moneyhash_payment_provider ||= payment_provider(provider_customer.customer)
        end

        def moneyhash_payment_method_id
          payment.payment_method&.provider_method_id || provider_customer.payment_method_id
        end

        def prepare_failed_result(error, reraise: false)
          result.error_message = error.error_body
          result.error_code = error.error_code
          result.reraise = reraise

          payment.update!(status: :failed, payable_payment_status: :failed)

          result.service_failure!(code: "moneyhash_error", message: "#{error.error_code}: #{error.error_body}")
        end
      end
    end
  end
end
