# frozen_string_literal: true

module PaymentProviders
  module Adyen
    class HandleEventService < BaseService
      PAYMENT_SERVICE_CLASS_MAP = {
        "Invoice" => Invoices::Payments::AdyenService,
        "PaymentRequest" => PaymentRequests::Payments::AdyenService
      }.freeze

      def initialize(organization:, event_json:)
        @organization = organization
        @event_json = event_json

        super
      end

      def call
        if PaymentProviders::AdyenProvider::IGNORED_WEBHOOK_EVENTS.include?(event["eventCode"])
          return result
        end

        unless PaymentProviders::AdyenProvider::WEBHOOKS_EVENTS.include?(event["eventCode"])
          return result.service_failure!(
            code: "webhook_error",
            message: "Invalid adyen event code: #{event["eventCode"]}"
          )
        end

        case event["eventCode"]
        when "AUTHORISATION"
          amount = event.dig("amount", "value")
          payment_type = event.dig("additionalData", "metadata.payment_type")

          if payment_type == "one-time"
            update_result = update_payment_status(payment_type)
            return update_result.raise_if_error!
          end

          return result if amount != 0

          service = PaymentProviderCustomers::AdyenService.new

          result = service.preauthorise(organization, event)
          result.raise_if_error!
        when "CANCELLATION"
          # Adyen uses originalReference to point at the cancelled payment;
          # pspReference is the cancel modification's own id.
          return result if event["success"] != "true"

          provider_payment_id = event["originalReference"]
          payment = Payment.find_by(provider_payment_id:) if provider_payment_id
          return result unless payment

          metadata = {lago_payable_type: payment.payable_type}
          update_result = payment_service_klass(metadata)
            .new
            .update_payment_status(provider_payment_id:, status: "Cancelled", metadata:)
          update_result.raise_if_error!
        when "REFUND"
          service = CreditNotes::Refunds::AdyenService.new

          provider_refund_id = event["pspReference"]
          status = (event["success"] == "true") ? :succeeded : :failed

          result = service.update_status(provider_refund_id:, status:)
          result.raise_if_error!
        when "CHARGEBACK"
          PaymentProviders::Adyen::Webhooks::ChargebackService.call(
            organization_id: organization.id,
            event_json:
          )
        when "REFUND_FAILED"
          return result if event["success"] != "true"

          service = CreditNotes::Refunds::AdyenService.new

          provider_refund_id = event["pspReference"]

          result = service.update_status(provider_refund_id:, status: :failed)
          result.raise_if_error!
        end
      end

      private

      attr_reader :organization, :event_json

      def event
        @event ||= JSON.parse(event_json)
      end

      def update_payment_status(payment_type)
        provider_payment_id = event["pspReference"]
        status = (event["success"] == "true") ? "succeeded" : "failed"
        metadata = {
          payment_type:,
          lago_invoice_id: event.dig("additionalData", "metadata.lago_invoice_id"),
          lago_payable_id: event.dig("additionalData", "metadata.lago_payable_id"),
          lago_payable_type: event.dig("additionalData", "metadata.lago_payable_type")
        }

        payment_service_klass(metadata).new.update_payment_status(
          provider_payment_id:,
          status:,
          amount_cents: event.dig("amount", "value"),
          metadata:
        )
      end

      def payment_service_klass(metadata)
        payable_type = metadata[:lago_payable_type] || "Invoice"

        PAYMENT_SERVICE_CLASS_MAP.fetch(payable_type) do
          raise NameError, "Invalid lago_payable_type: #{payable_type}"
        end
      end
    end
  end
end
