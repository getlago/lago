# frozen_string_literal: true

module PaymentRequests
  module Payments
    class GeneratePaymentUrlService < BaseService
      include Customers::PaymentProviderFinder

      PROVIDER_GOCARDLESS = "gocardless"

      def initialize(payable:)
        @payable = payable
        @provider = payable.customer.payment_provider.to_s

        super
      end

      def call
        return result.single_validation_failure!(error_code: "no_linked_payment_provider") if provider.blank?
        return result.single_validation_failure!(error_code: "invalid_payment_provider") if gocardless_provider?
        return result.single_validation_failure!(error_code: "invalid_payment_status") if payable.payment_succeeded?

        if current_payment_provider.blank?
          return result.single_validation_failure!(error_code: "missing_payment_provider")
        end

        if !current_payment_provider_customer ||
            current_payment_provider_customer.provider_customer_id.blank? && current_payment_provider_customer&.require_provider_payment_id?
          return result.single_validation_failure!(error_code: "missing_payment_provider_customer")
        end

        payment_url_result = PaymentRequests::Payments::PaymentProviders::Factory.new_instance(payable:).generate_payment_url
        payment_url_result.raise_if_error!

        return result.single_validation_failure!(error_code: "payment_provider_error") if payment_url_result.payment_url.blank?

        payment_url_result
      rescue BaseService::ThirdPartyFailure => e
        deliver_error_webhook(e)

        e.result
      rescue BaseService::FailedResult => e
        e.result
      end

      private

      attr_reader :payable, :provider

      delegate :customer, to: :payable

      def gocardless_provider?
        provider == PROVIDER_GOCARDLESS
      end

      def current_payment_provider_customer
        @current_payment_provider_customer ||= customer.payment_provider_customers
          .find_by(payment_provider_id: current_payment_provider.id)
      end

      def current_payment_provider
        @current_payment_provider ||= payment_provider(customer)
      end

      def deliver_error_webhook(payment_url_result)
        DeliverErrorWebhookService.call_async(payable, {
          provider_customer_id: current_payment_provider_customer.provider_customer_id,
          provider_error: {
            message: payment_url_result.error_message,
            error_code: payment_url_result.error_code
          }
        })
      end
    end
  end
end
