# frozen_string_literal: true

module Invoices
  module Payments
    class AdyenService < BaseService
      include Lago::Adyen::ErrorHandlable
      include Customers::PaymentProviderFinder

      PROVIDER_NAME = "Adyen"

      def initialize(invoice = nil)
        @invoice = invoice

        super
      end

      def update_payment_status(provider_payment_id:, status:, amount_cents: nil, metadata: {})
        payment = if metadata[:payment_type] == "one-time"
          create_payment(provider_payment_id:, amount_cents:, metadata:)
        else
          Payment.find_by(provider_payment_id:)
        end
        return result.not_found_failure!(resource: "adyen_payment") unless payment

        result.payment = payment
        result.invoice = payment.payable
        return result if payment.payable.payment_succeeded?

        payment.status = status

        payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
        payment.payable_payment_status = payable_payment_status
        payment.save!

        deliver_webhook if payable_payment_status.to_sym == :succeeded

        update_invoice_payment_status(payment_status: payable_payment_status)

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      def generate_payment_url(payment_intent)
        res = client.checkout.payment_links_api.payment_links(
          Lago::Adyen::Params.new(payment_url_params(payment_intent)).to_h,
          headers: {"Idempotency-Key" => payment_intent.id}
        )

        adyen_success, adyen_error = handle_adyen_response(res)
        result.service_failure!(code: adyen_error.code, message: adyen_error.msg) unless adyen_success

        return result unless result.success?

        result.payment_url = res.response["url"]

        result
      rescue Adyen::AdyenError => e
        result.third_party_failure!(third_party: PROVIDER_NAME, error_code: e.code, error_message: e.msg)
      end

      private

      attr_accessor :invoice

      delegate :organization, :customer, to: :invoice

      def create_payment(provider_payment_id:, metadata:, amount_cents: nil)
        @invoice = Invoice.find(metadata[:lago_invoice_id])

        increment_payment_attempts

        Payment.new(
          organization_id: invoice.organization_id,
          payable: invoice,
          customer:,
          payment_provider_id: adyen_payment_provider.id,
          payment_provider_customer_id: customer.adyen_customer.id,
          amount_cents: amount_cents || invoice.total_due_amount_cents,
          amount_currency: invoice.currency.upcase,
          provider_payment_id:
        )
      end

      def client
        @client ||= Adyen::Client.new(
          api_key: adyen_payment_provider.api_key,
          env: adyen_payment_provider.environment,
          live_url_prefix: adyen_payment_provider.live_prefix
        )
      end

      def success_redirect_url
        adyen_payment_provider.success_redirect_url.presence || ::PaymentProviders::AdyenProvider::SUCCESS_REDIRECT_URL
      end

      def adyen_payment_provider
        @adyen_payment_provider ||= payment_provider(customer)
      end

      def payment_url_params(payment_intent)
        prms = {
          reference: invoice.number,
          amount: {
            value: invoice.total_due_amount_cents,
            currency: invoice.currency.upcase
          },
          merchantAccount: adyen_payment_provider.merchant_account,
          returnUrl: success_redirect_url,
          shopperReference: customer.external_id,
          storePaymentMethodMode: "enabled",
          recurringProcessingModel: "UnscheduledCardOnFile",
          expiresAt: payment_intent.expires_at.iso8601,
          metadata: {
            lago_customer_id: customer.id,
            lago_invoice_id: invoice.id,
            invoice_issuing_date: invoice.issuing_date.iso8601,
            invoice_type: invoice.invoice_type,
            payment_type: "one-time"
          }
        }
        prms[:shopperEmail] = customer.email if customer.email
        prms
      end

      def update_invoice_payment_status(payment_status:, deliver_webhook: true)
        params = {
          payment_status:,
          ready_for_payment_processing: payment_status.to_sym != :succeeded
        }

        if payment_status.to_sym == :succeeded
          total_paid_amount_cents = invoice.payments.where(payable_payment_status: :succeeded).sum(:amount_cents)
          params[:total_paid_amount_cents] = total_paid_amount_cents
        end

        result = Invoices::UpdateService.call(
          invoice:,
          params:,
          webhook_notification: deliver_webhook
        )
        result.raise_if_error!
      end

      def increment_payment_attempts
        invoice.update!(payment_attempts: invoice.payment_attempts + 1)
      end

      def deliver_webhook
        SendWebhookJob.perform_later("payment.succeeded", result.payment)
      end

      def deliver_error_webhook(adyen_error)
        DeliverErrorWebhookService.call_async(invoice, {
          provider_customer_id: customer.adyen_customer.provider_customer_id,
          provider_error: {
            message: adyen_error.msg,
            error_code: adyen_error.code
          }
        })
      end
    end
  end
end
