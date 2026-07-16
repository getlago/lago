# frozen_string_literal: true

module PaymentRequests
  module Payments
    class AdyenService < BaseService
      include Lago::Adyen::ErrorHandlable
      include Customers::PaymentProviderFinder
      include Updatable

      PROVIDER_NAME = "Adyen"

      def initialize(payable = nil)
        @payable = payable

        super(nil)
      end

      def generate_payment_url
        result_url = client.checkout.payment_links_api.payment_links(
          Lago::Adyen::Params.new(payment_url_params).to_h
        )

        adyen_success, adyen_error = handle_adyen_response(result_url)
        return result.service_failure!(code: adyen_error.code, message: adyen_error.msg) unless adyen_success

        result.payment_url = result_url.response["url"]

        result
      rescue Adyen::AdyenError => e
        result.third_party_failure!(third_party: PROVIDER_NAME, error_code: e.code, error_message: e.msg)
      end

      def update_payment_status(provider_payment_id:, status:, amount_cents: nil, metadata: {})
        payment = if metadata[:payment_type] == "one-time"
          create_payment(provider_payment_id:, metadata:)
        else
          Payment.find_by(provider_payment_id:)
        end
        return result.not_found_failure!(resource: "adyen_payment") unless payment

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

      attr_accessor :payable

      delegate :organization, :customer, to: :payable

      def client
        @client ||= Adyen::Client.new(
          api_key: adyen_payment_provider.api_key,
          env: adyen_payment_provider.environment,
          live_url_prefix: adyen_payment_provider.live_prefix
        )
      end

      def adyen_payment_provider
        @adyen_payment_provider ||= payment_provider(customer)
      end

      def payment_url_params
        prms = {
          reference: "Overdue invoices",
          amount: {
            value: payable.total_amount_cents,
            currency: payable.currency.upcase
          },
          merchantAccount: adyen_payment_provider.merchant_account,
          returnUrl: success_redirect_url,
          shopperReference: customer.external_id,
          storePaymentMethodMode: "enabled",
          recurringProcessingModel: "UnscheduledCardOnFile",
          expiresAt: Time.current + 70.days, # max link TTL
          metadata: {
            lago_customer_id: customer.id,
            lago_payable_id: payable.id,
            lago_payable_type: payable.class.name,
            payment_type: "one-time"
          }
        }
        prms[:shopperEmail] = customer.email if customer.email
        prms
      end

      def success_redirect_url
        adyen_payment_provider.success_redirect_url.presence || ::PaymentProviders::AdyenProvider::SUCCESS_REDIRECT_URL
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

      def create_payment(provider_payment_id:, metadata:)
        @payable = PaymentRequest.find(metadata[:lago_payable_id])

        payable.increment_payment_attempts!

        Payment.new(
          organization_id: payable.organization_id,
          payable:,
          customer:,
          payment_provider_id: adyen_payment_provider.id,
          payment_provider_customer_id: customer.adyen_customer.id,
          amount_cents: payable.total_amount_cents,
          amount_currency: payable.currency.upcase,
          provider_payment_id:
        )
      end

      def deliver_error_webhook(adyen_error)
        DeliverErrorWebhookService.call_async(payable, {
          provider_customer_id: customer.adyen_customer.provider_customer_id,
          provider_error: {
            message: adyen_error.msg,
            error_code: adyen_error.code
          }
        })
      end

      def reset_customer_dunning_campaign_status(payment_status)
        return unless payment_status_succeeded?(payment_status)
        return unless payable.try(:dunning_campaign)

        customer.reset_dunning_campaign_for_currency!(payable.currency)
      end
    end
  end
end
