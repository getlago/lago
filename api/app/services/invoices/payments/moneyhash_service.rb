# frozen_string_literal: true

module Invoices
  module Payments
    class MoneyhashService < BaseService
      include Customers::PaymentProviderFinder

      def initialize(invoice = nil)
        @invoice = invoice

        super(nil)
      end

      def update_payment_status(organization_id:, provider_payment_id:, status:, amount_cents: nil, metadata: {})
        payment_obj = Payment.find_or_initialize_by(provider_payment_id: provider_payment_id)
        payment = if payment_obj.persisted?
          payment_obj
        else
          create_payment(provider_payment_id:, amount_cents:, metadata:)
        end

        return handle_missing_payment(organization_id, metadata) unless payment

        result.payment = payment
        result.invoice = payment.payable
        return result if payment.payable.payment_succeeded?

        payment_status = payment.payment_provider.determine_payment_status(status)
        payable_payment_status = payment.payment_provider.payable_payment_status(status)

        payment.update!(status: payment_status, payable_payment_status:)

        deliver_webhook if payable_payment_status.to_sym == :succeeded

        update_invoice_payment_status(payment_status: payable_payment_status, processing: payment_status == :processing)

        result
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      def generate_payment_url(payment_intent)
        return result unless should_process_payment?

        response = client.post_with_response(
          payment_url_params(payment_intent),
          headers.merge!("X-Idempotency-Key" => payment_intent.id)
        )
        moneyhash_result = JSON.parse(response.body)

        return result unless moneyhash_result

        moneyhash_result_data = moneyhash_result["data"]
        result.payment_url = "#{moneyhash_result_data["embed_url"]}?lago_request=generate_payment_url"
        result
      rescue LagoHttpClient::HttpError => e
        deliver_error_webhook(e)
        result.service_failure!(code: e.error_code, message: e.message)
      end

      private

      attr_accessor :invoice

      delegate :organization, :customer, to: :invoice

      def handle_missing_payment(organization_id, metadata)
        return result unless metadata&.key?("lago_payable_id")

        invoice = Invoice.find_by(id: metadata["lago_payable_id"], organization_id:)
        return result if invoice.nil?
        return result if invoice.payment_failed?

        result.not_found_failure!(resource: "moneyhash_payment")
      end

      def update_invoice_payment_status(payment_status:, deliver_webhook: true, processing: false)
        result = Invoices::UpdateService.call(
          invoice: invoice.presence || @result.invoice,
          params: {
            payment_status:,
            ready_for_payment_processing: !processing && payment_status.to_sym != :succeeded
          },
          webhook_notification: deliver_webhook
        )
        result.raise_if_error!
      end

      def deliver_webhook
        SendWebhookJob.perform_later("payment.succeeded", result.payment)
      end

      def increment_payment_attempts
        invoice.update!(payment_attempts: invoice.payment_attempts + 1)
      end

      def create_payment(provider_payment_id:, metadata:, amount_cents: nil)
        @invoice ||= Invoice.find_by(id: metadata["lago_payable_id"])
        unless @invoice
          result.not_found_failure!(resource: "invoice")
          return
        end

        increment_payment_attempts

        Payment.new(
          organization_id: @invoice.organization_id,
          payable: invoice,
          customer:,
          payment_provider_id: moneyhash_payment_provider.id,
          payment_provider_customer_id: customer.moneyhash_customer.id,
          amount_cents: amount_cents || invoice.total_amount_cents,
          amount_currency: invoice.currency&.upcase,
          provider_payment_id:
        )
      end

      def should_process_payment?
        return false if invoice.payment_succeeded? || invoice.voided?
        return false if moneyhash_payment_provider.blank?

        customer&.moneyhash_customer&.provider_customer_id
      end

      def client
        @client || LagoHttpClient::Client.new("#{::PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/payments/intent/")
      end

      def headers
        {
          "Content-Type" => "application/json",
          "x-Api-Key" => moneyhash_payment_provider.api_key
        }
      end

      def moneyhash_payment_provider
        @moneyhash_payment_provider ||= payment_provider(customer)
      end

      def payment_url_params(payment_intent)
        params = {
          amount: invoice.total_due_amount_cents.div(100).to_f,
          amount_currency: invoice.currency.upcase,
          flow_id: moneyhash_payment_provider.flow_id,
          billing_data: invoice.customer.moneyhash_customer.mh_billing_data,
          customer: invoice.customer.moneyhash_customer.provider_customer_id,
          webhook_url: moneyhash_payment_provider.webhook_end_point,
          merchant_initiated: false,
          expires_after_seconds: (payment_intent.expires_at - Time.current).to_i,
          custom_fields: {
            # payable
            lago_payable_id: invoice.id,
            lago_payable_type: invoice.class.name,
            lago_payable_invoice_type: invoice.invoice_type,
            # mit flag
            lago_mit: false,
            # service
            lago_mh_service: "Invoices::Payments::MoneyhashService",
            # request
            lago_request: "generate_payment_url"
          }
        }

        params[:custom_fields].merge!(customer.moneyhash_customer.mh_custom_fields)

        # Include subscription data for subscription invoices
        if invoice.invoice_type == "subscription"
          params[:custom_fields].merge!(
            lago_plan_id: invoice.subscriptions&.first&.plan_id.to_s,
            lago_subscription_external_id: invoice.subscriptions&.first&.external_id.to_s
          )
        end

        # Tokenize card if the customer doesn't have a saved one
        if customer.moneyhash_customer.provider_customer_id.blank?
          params.merge!(
            tokenize_card: true,
            payment_type: "UNSCHEDULED",
            recurring_data: {
              agreement_id: customer.id
            }
          )
        end

        params
      end

      def deliver_error_webhook(moneyhash_error)
        DeliverErrorWebhookService.call_async(invoice, {
          provider_customer_id: customer.moneyhash_customer.provider_customer_id,
          provider_error: {
            message: moneyhash_error.message,
            error_code: moneyhash_error.error_code
          }
        })
      end
    end
  end
end
