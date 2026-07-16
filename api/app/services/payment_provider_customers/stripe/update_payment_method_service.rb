# frozen_String_literal: true

module PaymentProviderCustomers
  module Stripe
    class UpdatePaymentMethodService < BaseService
      def initialize(stripe_customer:, payment_method_id:, payment_method_details: {})
        @stripe_customer = stripe_customer
        @payment_method_id = payment_method_id
        @payment_method_details = payment_method_details

        super
      end

      def call
        return result.not_found_failure!(resource: "stripe_customer") unless stripe_customer
        return result.service_failure!(code: :deleted_customer, message: "Customer associated to this stripe customer was deleted") if deleted_customer

        stripe_customer.payment_method_id = payment_method_id
        stripe_customer.save!

        find_or_create_result = PaymentMethods::FindOrCreateFromProviderService.call(
          customer:,
          payment_provider_customer: stripe_customer,
          provider_method_id: payment_method_id,
          params: {
            provider_payment_methods: stripe_customer.provider_payment_methods,
            details: payment_method_details
          },
          set_as_default: true
        )
        result.payment_method = find_or_create_result.payment_method

        reprocess_pending_invoices

        result.stripe_customer = stripe_customer
        result
      end

      private

      attr_reader :stripe_customer, :payment_method_id, :payment_method_details

      def customer
        @customer ||= stripe_customer.customer
      end

      def deleted_customer
        customer.nil? &&
          Customer.unscoped.where(organization_id: stripe_customer.organization_id, id: stripe_customer.customer_id).where.not(deleted_at: nil).count > 0
      end

      def reprocess_pending_invoices
        invoices = customer.invoices
          .payment_pending
          .where(ready_for_payment_processing: true)
          .where(status: "finalized")

        invoices.find_each do |invoice|
          Invoices::Payments::CreateJob.perform_later(invoice:, payment_provider: :stripe)
        end
      end
    end
  end
end
