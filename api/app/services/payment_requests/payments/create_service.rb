# frozen_string_literal: true

module PaymentRequests
  module Payments
    class CreateService < BaseService
      include Customers::PaymentProviderFinder
      include Updatable

      Result = BaseResult[:payable, :payment, :payment_provider]

      def initialize(payable:, payment_provider: nil, payment_method_params: {})
        @payable = payable
        @provider = payment_provider&.to_sym
        @payment_method_params = payment_method_params

        super
      end

      def call
        return result.not_found_failure!(resource: "payment_provider") unless provider

        result.payable = payable
        return result unless should_process_payment?

        unless payable.total_amount_cents.positive?
          update_payable_payment_status(payment_status: :succeeded)
          return result
        end

        if processing_payment
          # Payment is being processed, return the existing payment
          # Status will be updated via webhooks
          result.payment = processing_payment
          return result
        end

        payable.increment_payment_attempts!

        payment ||= Payment.create_with(
          organization_id: payable.organization_id,
          payment_provider_id: current_payment_provider.id,
          payment_provider_customer_id: current_payment_provider_customer.id,
          amount_cents: payable.total_amount_cents,
          amount_currency: payable.currency,
          status: "pending",
          customer_id: payable.customer_id
        ).find_or_create_by!(
          payable:,
          payable_payment_status: "pending"
        )

        payment.payment_method_id = determine_payment_method&.id
        payment.save!

        result.payment = payment

        payment_result = ::PaymentProviders::CreatePaymentFactory.new_instance(
          provider:,
          payment:,
          reference: "#{payable.billing_entity.name} - Overdue invoices",
          metadata: {
            lago_customer_id: payable.customer_id,
            lago_payable_id: payable.id,
            lago_payable_type: payable.class.name
          }
        ).call!

        update_payable_payment_status(payment_status: payment_result.payment.payable_payment_status)
        update_invoices_payment_status(payment_status: payment_result.payment.payable_payment_status)
        update_invoices_paid_amount_cents(payment_status: payment_result.payment.payable_payment_status)

        PaymentReceipts::CreateJob.perform_later(payment) if payment.payable.organization.issue_receipts_enabled?

        PaymentRequestMailer.with(payment_request: payable).requested.deliver_later if payable.payment_failed?

        result
      rescue Invoices::Payments::AlreadyPaidError
        # The payment request was settled by another payment so we can drop the unused pending payment
        result.payment&.destroy if result.payment&.provider_payment_id.nil?
        result.payment = nil
        result
      rescue BaseService::ServiceFailure => e
        PaymentRequestMailer.with(payment_request: payable).requested.deliver_later
        result.payment = e.result.payment
        deliver_error_webhook(e.result)
        update_payable_payment_status(payment_status: e.result.payment.payable_payment_status)

        # Some errors should be investigated and need to be raised
        raise if e.result.reraise

        result
      end

      def call_async
        return result.not_found_failure!(resource: "payment_provider") unless provider

        PaymentRequests::Payments::CreateJob.perform_later(payable:, payment_provider: provider, payment_method_params:)

        result.payment_provider = provider
        result
      end

      private

      attr_reader :payable, :payment_method_params

      delegate :customer, :organization, to: :payable

      def provider
        @provider ||= payable.customer.payment_provider&.to_sym
      end

      def should_process_payment?
        return false if payable.payment_succeeded?
        return false if current_payment_provider.blank?
        return false unless current_payment_provider_customer&.provider_customer_id

        payable.invoices.all?(&:ready_for_payment_processing)
      end

      def current_payment_provider
        @current_payment_provider ||= payment_provider(customer)
      end

      def current_payment_provider_customer
        @current_payment_provider_customer ||= customer.payment_provider_customers
          .find_by(payment_provider_id: current_payment_provider.id)
      end

      def update_payable_payment_status(payment_status:)
        PaymentRequests::UpdateService.call!(
          payable: payable,
          params: {
            # NOTE: A proper `processing` payment status should be introduced for invoices
            payment_status: (payment_status.to_s == "processing") ? :pending : payment_status,
            ready_for_payment_processing: payment_status.to_sym == :failed
          },
          webhook_notification: payment_status.to_sym == :succeeded
        )
      end

      def update_invoices_payment_status(payment_status:)
        payable.invoices.each do |invoice|
          next if invoice.payment_succeeded? && payment_status.to_sym != :succeeded

          Invoices::UpdateService.call!(
            invoice:,
            params: {
              # NOTE: A proper `processing` payment status should be introduced for invoices
              payment_status: (payment_status.to_s == "processing") ? :pending : payment_status,
              ready_for_payment_processing: payment_status.to_sym == :failed
            },
            webhook_notification: payment_status.to_sym == :succeeded
          )
        end
      end

      def deliver_error_webhook(payment_result)
        DeliverErrorWebhookService.call_async(payable, {
          provider_customer_id: current_payment_provider_customer.provider_customer_id,
          provider_error: {
            message: payment_result.error_message,
            error_code: payment_result.error_code
          }
        })
      end

      def processing_payment
        @processing_payment ||= Payment.find_by(
          payable_id: payable.id,
          payment_provider_id: current_payment_provider.id,
          payment_provider_customer_id: current_payment_provider_customer.id,
          amount_cents: payable.total_amount_cents,
          amount_currency: payable.currency,
          payable_payment_status: "processing"
        )
      end

      def determine_payment_method
        @determine_payment_method ||= if payment_method_params.present?
          determine_override_payment_method
        else
          customer.default_payment_method
        end
      end

      def determine_override_payment_method
        return nil if payment_method_params[:payment_method_type] == "manual"

        if payment_method_params[:payment_method_id].present?
          customer.payment_methods.find_by(id: payment_method_params[:payment_method_id])
        else
          customer.default_payment_method
        end
      end
    end
  end
end
