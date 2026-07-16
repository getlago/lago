# frozen_string_literal: true

module PaymentRequests
  module Payments
    class StripeService < BaseService
      include Customers::PaymentProviderFinder
      include Updatable

      PROVIDER_NAME = "Stripe"

      def initialize(payable = nil)
        @payable = payable

        super(nil)
      end

      def generate_payment_url
        result_url = ::Stripe::Checkout::Session.create(
          payment_url_payload,
          {
            api_key: stripe_api_key
          }
        )

        result.payment_url = result_url["url"]

        result
      rescue ::Stripe::CardError, ::Stripe::InvalidRequestError, ::Stripe::AuthenticationError, Stripe::PermissionError => e
        result.third_party_failure!(third_party: PROVIDER_NAME, error_code: e.code, error_message: e.message)
      end

      def update_payment_status(organization_id:, status:, stripe_payment:, amount_cents: nil)
        payment = Payment.find_by(provider_payment_id: stripe_payment.id)
        return result if payment&.payable&.organization_id.present? && payment.payable.organization_id != organization_id

        if !payment && stripe_payment.metadata[:payment_type] == "one-time"
          payment = create_payment(stripe_payment)
        end

        payment ||= handle_missing_payment(organization_id, stripe_payment)

        return result unless payment

        if payment.payable.payment_succeeded?
          if payment.persisted?
            result.payment = payment
            result.payable = payment.payable
          end

          return result
        end

        processing = status == "processing"
        payment.status = status

        payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
        payment.payable_payment_status = payable_payment_status
        payment.save!

        result.payment = payment
        result.payable = payment.payable

        update_payable_payment_status(payment_status: payable_payment_status, processing:)
        update_invoices_payment_status(payment_status: payable_payment_status, processing:)
        update_invoices_paid_amount_cents(payment_status: payable_payment_status)
        reset_customer_dunning_campaign_status(payable_payment_status)

        PaymentRequestMailer.with(payment_request: payment.payable).requested.deliver_later if result.payable.payment_failed?

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue ActiveRecord::RecordNotUnique
        # NOTE: Another writer (a parallel webhook worker, or PaymentProviders::Stripe::Payments::CreateService)
        #       committed the Payment first. Return the persisted row so the
        #       caller can still enqueue downstream side effects (e.g. SetPaymentMethodAndCreateReceiptJob).
        payment = Payment.find_by(provider_payment_id: stripe_payment.id)
        if payment
          result.payment = payment
          result.payable = payment.payable
        end
        result
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      private

      attr_accessor :payable

      delegate :organization, :customer, to: :payable

      def success_redirect_url
        stripe_payment_provider.success_redirect_url.presence ||
          ::PaymentProviders::StripeProvider::SUCCESS_REDIRECT_URL
      end

      def stripe_api_key
        stripe_payment_provider.secret_key
      end

      def description
        desc = "#{customer.billing_entity.name} - Overdue invoices"

        if payable.invoices.one?
          "#{desc}: #{payable.invoices.first.number}"
        else
          desc
        end
      end

      def update_payable_payment_status(payment_status:, deliver_webhook: true, processing: false)
        UpdateService.call(
          payable: result.payable,
          params: {
            payment_status:,
            # NOTE: A proper `processing` payment status should be introduced for payment_requests
            ready_for_payment_processing: !processing && !payment_status_succeeded?(payment_status)
          },
          webhook_notification: deliver_webhook
        ).raise_if_error!
      end

      def update_invoices_payment_status(payment_status:, deliver_webhook: true, processing: false)
        result.payable.invoices.each do |invoice|
          next if invoice.payment_succeeded? && !payment_status_succeeded?(payment_status)

          Invoices::UpdateService.call(
            invoice: invoice,
            params: {
              payment_status:,
              # NOTE: A proper `processing` payment status should be introduced for invoices
              ready_for_payment_processing: !processing && !payment_status_succeeded?(payment_status)
            },
            webhook_notification: deliver_webhook
          ).raise_if_error!
        end
      end

      def line_items
        payable.invoices.map do |invoice|
          {
            quantity: 1,
            price_data: {
              currency: invoice.currency.downcase,
              unit_amount: invoice.total_due_amount_cents,
              product_data: {name: invoice.number}
            }
          }
        end
      end

      def payment_url_payload
        {
          line_items: line_items,
          mode: "payment",
          success_url: success_redirect_url,
          customer: customer.stripe_customer.provider_customer_id,
          payment_method_types: customer.stripe_customer.provider_payment_methods,
          payment_intent_data: {
            description:,
            metadata: {
              lago_customer_id: customer.id,
              lago_payable_id: payable.id,
              lago_payable_type: payable.class.name,
              payment_type: "one-time"
            }
          }
        }
      end

      def handle_missing_payment(organization_id, stripe_payment)
        # NOTE: Payment was not initiated by lago
        return unless stripe_payment.metadata&.key?(:lago_payable_id)

        # NOTE: Payment Request does not belong to this lago organization
        #       It means the same Stripe secret key is used for multiple organizations
        payment_request = PaymentRequest.find_by(id: stripe_payment.metadata[:lago_payable_id], organization_id:)
        return unless payment_request

        # NOTE: Payment Request exists but payment status is failed
        return if payment_request.payment_failed?

        # NOTE: For some reason payment is missing in the database... (killed sidekiq job, etc.)
        #       We have to recreate it from the received data
        create_payment(stripe_payment, payable: payment_request)
      end

      def create_payment(stripe_payment, payable: nil)
        @payable = payable || PaymentRequest.find_by(id: stripe_payment.metadata[:lago_payable_id])

        unless @payable
          result.not_found_failure!(resource: "payment_request")
          return
        end

        @payable.increment_payment_attempts!

        Payment.new(
          organization_id: @payable.organization_id,
          payable: @payable,
          customer:,
          payment_provider_id: stripe_payment_provider.id,
          payment_provider_customer_id: customer.stripe_customer.id,
          amount_cents: @payable.total_amount_cents,
          amount_currency: @payable.currency,
          provider_payment_id: stripe_payment.id
        )
      end

      def deliver_error_webhook(stripe_error)
        DeliverErrorWebhookService.call_async(payable, {
          provider_customer_id: customer.stripe_customer.provider_customer_id,
          provider_error: {
            message: stripe_error.message,
            error_code: stripe_error.code
          }
        })
      end

      def stripe_payment_provider
        @stripe_payment_provider ||= payment_provider(customer)
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
