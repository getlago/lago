# frozen_string_literal: true

module Invoices
  module Payments
    class StripeService < BaseService
      include Customers::PaymentProviderFinder

      PROVIDER_NAME = "Stripe"

      def initialize(invoice = nil)
        @invoice = invoice

        super
      end

      def update_payment_status(organization_id:, status:, stripe_payment:, amount_cents: nil)
        payment = Payment.find_by(provider_payment_id: stripe_payment.id)
        return result if payment&.payable&.organization_id.present? && payment.payable.organization_id != organization_id

        if !payment && stripe_payment.metadata[:payment_type] == "one-time"
          payment = create_payment(stripe_payment, amount_cents:)
        end

        unless payment
          handle_missing_payment(organization_id, stripe_payment)
          return result unless result.payment

          payment = result.payment
        end

        result.payment = payment
        result.invoice = payment.payable
        return result if payment.payable.payment_succeeded?

        payment.status = status

        payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
        payment.payable_payment_status = payable_payment_status
        payment.error_code = stripe_payment.error_code if stripe_payment.error_code
        payment.save!

        deliver_webhook if payable_payment_status.to_sym == :succeeded

        if status.to_s == "failed" && result.invoice.payments.excluding(result.payment).where(status: :requires_action).any?
          # We don't update the invoice status because it's likely the webhook of a failed payment
          # but there is already a retry in progress with 3DSecure authentication
        else
          update_invoice_payment_status(
            payment_status: payable_payment_status,
            processing: status == "processing"
          )
        end

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue ActiveRecord::RecordNotUnique
        result
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      def generate_payment_url(payment_intent)
        res = ::Stripe::Checkout::Session.create(
          payment_url_payload(payment_intent),
          {
            api_key: stripe_api_key,
            idempotency_key: "payment-intent-#{payment_intent.id}"
          }
        )

        result.payment_url = res["url"]
        result.provider_session_id = res["id"]

        result
      rescue ::Stripe::CardError, ::Stripe::InvalidRequestError, ::Stripe::AuthenticationError, Stripe::PermissionError => e
        result.third_party_failure!(third_party: PROVIDER_NAME, error_code: e.code, error_message: e.message)
      end

      # NOTE: Expires the hosted Stripe Checkout open Session so it can no longer be paid.
      def expire_payment_url(payment_intent)
        return result if payment_intent.provider_session_id.blank?

        session = ::Stripe::Checkout::Session.retrieve(
          payment_intent.provider_session_id,
          {api_key: stripe_api_key}
        )

        return result unless session.status == "open"

        ::Stripe::Checkout::Session.expire(
          payment_intent.provider_session_id,
          {},
          {api_key: stripe_api_key}
        )

        result
      rescue ::Stripe::InvalidRequestError # the other ones are on the retry job
        result
      end

      private

      attr_accessor :invoice

      delegate :organization, :customer, to: :invoice

      def create_payment(stripe_payment, invoice: nil, amount_cents: nil)
        @invoice = invoice || Invoice.find_by(id: stripe_payment.metadata[:lago_invoice_id])
        unless @invoice
          result.not_found_failure!(resource: "invoice")
          return
        end

        increment_payment_attempts

        payment = Payment.find_or_initialize_by(
          organization: @invoice.organization,
          payable: @invoice,
          customer:,
          payment_provider_id: stripe_payment_provider.id,
          payment_provider_customer_id: customer.stripe_customer.id,
          amount_cents: amount_cents || @invoice.total_due_amount_cents,
          amount_currency: @invoice.currency,
          status: "pending"
        )

        status = payment.payment_provider&.determine_payment_status(stripe_payment.status)
        status = (status.to_sym == :pending) ? :processing : status

        payment.provider_payment_id = stripe_payment.id
        payment.status = stripe_payment.status
        payment.payable_payment_status = status
        payment.save!
        payment
      end

      def success_redirect_url
        stripe_payment_provider.success_redirect_url.presence ||
          ::PaymentProviders::StripeProvider::SUCCESS_REDIRECT_URL
      end

      def stripe_api_key
        stripe_payment_provider.secret_key
      end

      def payment_url_payload(payment_intent)
        {
          line_items: [
            {
              quantity: 1,
              price_data: {
                currency: invoice.currency.downcase,
                unit_amount: invoice.total_due_amount_cents,
                product_data: {
                  name: invoice.number
                }
              }
            }
          ],
          mode: "payment",
          success_url: success_redirect_url,
          customer: customer.stripe_customer.provider_customer_id,
          payment_method_types: customer.stripe_customer.provider_payment_methods,
          expires_at: payment_intent.expires_at.to_i,
          payment_intent_data: {
            description:,
            setup_future_usage: setup_future_usage? ? "off_session" : nil,
            metadata: {
              lago_customer_id: customer.id,
              lago_invoice_id: invoice.id,
              invoice_issuing_date: invoice.issuing_date.iso8601,
              invoice_type: invoice.invoice_type,
              payment_type: "one-time"
            }
          }
        }
      end

      def description
        "#{organization.name} - Invoice #{invoice.number}"
      end

      def update_invoice_payment_status(payment_status:, deliver_webhook: true, processing: false)
        params = {
          payment_status:,
          # NOTE: A proper `processing` payment status should be introduced for invoices
          ready_for_payment_processing: !processing && payment_status.to_sym != :succeeded
        }

        if payment_status.to_sym == :succeeded
          total_paid_amount_cents = (invoice.presence || @result.invoice).payments.where(payable_payment_status: :succeeded).sum(:amount_cents)
          params[:total_paid_amount_cents] = total_paid_amount_cents
        end

        result = Invoices::UpdateService.call(
          invoice: invoice.presence || @result.invoice,
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

      def deliver_error_webhook(stripe_error)
        DeliverErrorWebhookService.call_async(invoice, {
          provider_customer_id: customer.stripe_customer.provider_customer_id,
          provider_error: {
            message: stripe_error.message,
            error_code: stripe_error.code
          }
        })
      end

      def handle_missing_payment(organization_id, stripe_payment)
        # NOTE: Payment was not initiated by lago
        return result unless stripe_payment.metadata&.key?(:lago_invoice_id)

        # NOTE: Invoice does not belong to this lago organization
        #       It means the same Stripe secret key is used for multiple organizations
        invoice = Invoice.find_by(id: stripe_payment.metadata[:lago_invoice_id], organization_id:)
        return result if invoice.nil?

        # NOTE: Invoice exists but payment status is failed
        return result if invoice.payment_failed?

        # NOTE: For some reason payment is missing in the database... (killed sidekiq job, etc.)
        #       We have to recreate it from the received data
        result.payment = create_payment(stripe_payment, invoice:)
        result
      end

      # NOTE: Due to RBI limitation, all indians payment should be "on session". See: https://docs.stripe.com/india-recurring-payments
      # crypto payments don't support 'off_session'
      def setup_future_usage?
        return false if customer.country == "IN"
        return false if customer.stripe_customer.provider_payment_methods.include?("crypto")

        true
      end

      def stripe_payment_provider
        @stripe_payment_provider ||= payment_provider(customer)
      end
    end
  end
end
