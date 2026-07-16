# frozen_string_literal: true

module Invoices
  module Payments
    class FlutterwaveService < BaseService
      include Customers::PaymentProviderFinder

      PROVIDER_NAME = "Flutterwave"

      def initialize(invoice = nil)
        @invoice = invoice

        super
      end

      def update_payment_status(organization_id:, status:, flutterwave_payment:, amount_cents: nil)
        payment = if flutterwave_payment.metadata[:payment_type] == "one-time"
          create_payment(flutterwave_payment, amount_cents:)
        else
          Payment.find_by(provider_payment_id: flutterwave_payment.id)
        end
        return result.not_found_failure!(resource: "flutterwave_payment") unless payment

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
        result.payment_url = payment_url
        result
      rescue LagoHttpClient::HttpError => e
        result.third_party_failure!(third_party: PROVIDER_NAME, error_code: e.error_code, error_message: e.error_body)
      end

      private

      attr_accessor :invoice

      delegate :organization, :customer, to: :invoice

      def payment_url
        response = create_checkout_session
        parsed_response = JSON.parse(response.body)

        parsed_response["data"]["link"]
      end

      def create_checkout_session
        body = {
          amount: Money.from_cents(invoice.total_amount_cents, invoice.currency).to_f,
          tx_ref: invoice.id,
          currency: invoice.currency.upcase,
          redirect_url: success_redirect_url,
          customer: customer_params,
          customizations: customizations_params,
          configuration: configuration_params,
          meta: meta_params
        }
        http_client.post_with_response(body, headers)
      end

      def customer_params
        {
          email: customer.email,
          phone_number: customer.phone || "",
          name: customer.name || customer.email
        }
      end

      def customizations_params
        {
          title: "#{organization.name} - Invoice Payment",
          description: "Payment for Invoice ##{invoice.number}",
          logo: organization.logo_url
        }.compact
      end

      def configuration_params
        {
          session_duration: 30
        }
      end

      def meta_params
        {
          lago_customer_id: customer.id,
          lago_invoice_id: invoice.id,
          lago_organization_id: organization.id,
          lago_invoice_number: invoice.number,
          payment_type: "one-time"
        }
      end

      def success_redirect_url
        flutterwave_payment_provider.success_redirect_url.presence ||
          ::PaymentProviders::FlutterwaveProvider::SUCCESS_REDIRECT_URL
      end

      def flutterwave_payment_provider
        @flutterwave_payment_provider ||= payment_provider(customer)
      end

      def headers
        {
          "Authorization" => "Bearer #{flutterwave_payment_provider.secret_key}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      end

      def http_client
        @http_client ||= LagoHttpClient::Client.new("#{flutterwave_payment_provider.api_url}/payments")
      end

      def create_payment(flutterwave_payment, amount_cents: nil)
        @invoice = Invoice.find_by(id: flutterwave_payment.metadata[:lago_invoice_id])

        increment_payment_attempts

        Payment.new(
          organization_id: @invoice.organization_id,
          payable: @invoice,
          customer:,
          payment_provider_id: flutterwave_payment_provider.id,
          payment_provider_customer_id: customer.flutterwave_customer.id,
          amount_cents: amount_cents || @invoice.total_due_amount_cents,
          amount_currency: @invoice.currency,
          provider_payment_id: flutterwave_payment.id
        )
      end

      def increment_payment_attempts
        invoice.update!(payment_attempts: invoice.payment_attempts + 1)
      end

      def update_invoice_payment_status(payment_status:, deliver_webhook: true)
        @invoice = result.invoice

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

      def deliver_webhook
        SendWebhookJob.perform_later("payment.succeeded", result.payment)
      end

      def deliver_error_webhook(flutterwave_error)
        DeliverErrorWebhookService.call_async(invoice, {
          provider_customer_id: customer.flutterwave_customer&.provider_customer_id,
          provider_error: {
            message: flutterwave_error.error_body,
            error_code: flutterwave_error.error_code
          }
        })
      end
    end
  end
end
