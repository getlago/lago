# frozen_string_literal: true

module PaymentRequests
  module Payments
    class FlutterwaveService < BaseService
      include Customers::PaymentProviderFinder
      include Updatable

      Result = BaseResult[:payable, :payment, :payment_url]

      def initialize(payable = nil)
        @payable = payable

        super(nil)
      end

      def call
        result.payment_url = payment_url
        result
      rescue LagoHttpClient::HttpError => e
        deliver_error_webhook(e)

        result.service_failure!(code: "action_script_runtime_error", message: e.message)
      end

      def update_payment_status(organization_id:, status:, flutterwave_payment:, amount_cents: nil)
        payment = if flutterwave_payment.metadata[:payment_type] == "one-time"
          create_payment(flutterwave_payment)
        else
          Payment.find_by(provider_payment_id: flutterwave_payment.id)
        end
        return result.not_found_failure!(resource: "flutterwave_payment") unless payment

        result.payment = payment
        result.payable = payment.payable
        return result if payment.payable.payment_succeeded?

        payment.status = status

        payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
        payment.payable_payment_status = payable_payment_status
        payment.save!

        update_payable_payment_status(payment_status: payable_payment_status)
        update_invoices_payment_status(payment_status: payable_payment_status)
        update_invoices_paid_amount_cents(payment_status: payable_payment_status)
        reset_customer_dunning_campaign_status(payable_payment_status)

        PaymentRequestMailer.with(payment_request: payment.payable).requested.deliver_later if result.payable.payment_failed?

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      private

      attr_reader :payable

      delegate :organization, :customer, to: :payable

      def payment_url
        response = create_checkout_session

        response["data"]["link"]
      end

      def create_checkout_session
        body = {
          amount: Money.from_cents(payable.total_amount_cents, payable.currency).to_f,
          tx_ref: "lago_payment_request_#{payable.id}",
          currency: payable.currency.upcase,
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
          title: "#{organization.name} - Payment Request",
          description: "Payment for invoices: #{invoice_numbers}",
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
          lago_payment_request_id: payable.id,
          lago_organization_id: organization.id,
          lago_invoice_ids: payable.invoices.pluck(:id).join(",")
        }
      end

      def invoice_numbers
        payable.invoices.pluck(:number).join(", ")
      end

      def success_redirect_url
        flutterwave_payment_provider.success_redirect_url.presence ||
          PaymentProviders::FlutterwaveProvider::SUCCESS_REDIRECT_URL
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
        @http_client ||= LagoHttpClient::Client.new(flutterwave_payment_provider.api_url)
      end

      def deliver_error_webhook(http_error)
        return unless payable.organization.webhook_endpoints.any?
        SendWebhookJob.perform_later(
          "payment_request.payment_failure",
          payable,
          provider_customer_id: flutterwave_customer&.provider_customer_id,
          provider_error: {
            message: http_error.message,
            error_code: http_error.error_code
          }
        )
      end

      def flutterwave_customer
        @flutterwave_customer ||= customer.flutterwave_customer
      end

      def create_payment(flutterwave_payment)
        @payable = PaymentRequest.find(flutterwave_payment.metadata[:lago_payable_id])

        payable.increment_payment_attempts!

        Payment.new(
          organization_id: payable.organization_id,
          payable:,
          customer:,
          payment_provider_id: flutterwave_payment_provider.id,
          payment_provider_customer_id: customer.flutterwave_customer.id,
          amount_cents: payable.total_amount_cents,
          amount_currency: payable.currency.upcase,
          provider_payment_id: flutterwave_payment.id
        )
      end

      def update_payable_payment_status(payment_status:, deliver_webhook: true)
        UpdateService.call(
          payable: result.payable,
          params: {
            payment_status:,
            ready_for_payment_processing: !payment_status_succeeded?(payment_status)
          },
          webhook_notification: deliver_webhook
        ).raise_if_error!
      end

      def update_invoices_payment_status(payment_status:, deliver_webhook: true)
        payable.invoices.each do |invoice|
          next if invoice.payment_succeeded? && !payment_status_succeeded?(payment_status)

          Invoices::UpdateService.call(
            invoice:,
            params: {
              payment_status:,
              ready_for_payment_processing: !payment_status_succeeded?(payment_status)
            },
            webhook_notification: deliver_webhook
          ).raise_if_error!
        end
      end

      def payment_status_succeeded?(payment_status)
        payment_status.to_sym == :succeeded
      end

      def reset_customer_dunning_campaign_status(payment_status)
        return unless payment_status_succeeded?(payment_status)
        return unless payable.try(:dunning_campaign)

        customer.reset_dunning_campaign_for_currency!(payable.currency)
      end
    end
  end
end
