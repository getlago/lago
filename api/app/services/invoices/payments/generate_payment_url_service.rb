# frozen_string_literal: true

module Invoices
  module Payments
    class GeneratePaymentUrlService < BaseService
      Result = BaseResult[:payment_url]

      include Customers::PaymentProviderFinder

      def initialize(invoice:)
        @invoice = invoice
        @provider = invoice&.customer&.payment_provider&.to_s

        super
      end

      def call
        return result.not_found_failure!(resource: "invoice") if invoice.blank?
        return result.single_validation_failure!(error_code: "no_linked_payment_provider") unless provider
        return result.single_validation_failure!(error_code: "invalid_payment_provider") if provider == "gocardless"

        if invoice.payment_succeeded? || invoice.voided? || invoice.draft?
          return result.single_validation_failure!(error_code: "invalid_invoice_status_or_payment_status")
        end

        if current_payment_provider.blank?
          return result.single_validation_failure!(error_code: "missing_payment_provider")
        end

        if !current_payment_provider_customer ||
            current_payment_provider_customer.provider_customer_id.blank? && current_payment_provider_customer&.require_provider_payment_id?
          return result.single_validation_failure!(error_code: "missing_payment_provider_customer")
        end

        payment_intent = PaymentIntents::FetchService.call!(invoice:).payment_intent

        result.payment_url = payment_intent.payment_url
        result
      rescue BaseService::ThirdPartyFailure => e
        deliver_error_webhook(e)

        e.result
      rescue BaseService::FailedResult => e
        e.result
      end

      private

      attr_reader :invoice, :provider

      delegate :customer, to: :invoice

      def current_payment_provider_customer
        @current_payment_provider_customer ||= customer.payment_provider_customers
          .find_by(payment_provider_id: current_payment_provider.id)
      end

      def current_payment_provider
        @current_payment_provider ||= payment_provider(customer)
      end

      def deliver_error_webhook(payment_url_failure)
        DeliverErrorWebhookService.call_async(invoice, {
          provider_customer_id: current_payment_provider_customer.provider_customer_id,
          provider_error: {
            message: payment_url_failure.error_message,
            error_code: payment_url_failure.error_code
          }
        })
      end
    end
  end
end
