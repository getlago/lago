# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Webhooks
      class SetupIntentSucceededService < BaseService
        include ::Customers::PaymentProviderFinder

        def call
          return result if stripe_customer_id.nil?
          return handle_missing_customer unless stripe_customer
          return result unless valid_payment_method?

          update_stripe_customer_default_payment_method
          result.payment_method_id = payment_method_id

          PaymentProviderCustomers::Stripe::UpdatePaymentMethodService.call(
            stripe_customer:,
            payment_method_id: payment_method_id,
            payment_method_details:
          ).raise_if_error!

          result.stripe_customer = stripe_customer
          result
        rescue ::Stripe::PermissionError => e
          result.service_failure!(code: "stripe_error", message: e.message)
        end

        private

        def stripe_customer
          @stripe_customer ||= PaymentProviderCustomers::StripeCustomer
            .by_provider_id_from_organization(organization.id, stripe_customer_id)
            .first
        end

        def stripe_customer_id
          event.data.object.customer
        end

        def payment_method_id
          event.data.object.payment_method
        end

        def valid_payment_method?
          stripe_payment_method.customer.present?
        end

        def stripe_payment_method
          @stripe_payment_method ||= ::Stripe::PaymentMethod.retrieve(
            payment_method_id,
            {api_key: stripe_payment_provider.secret_key}
          )
        end

        def payment_method_details
          card = stripe_payment_method.try(:card)

          PaymentMethods::CardDetails.new(
            type: stripe_payment_method.type,
            last4: card&.last4,
            brand: card&.display_brand,
            expiration_month: card&.exp_month,
            expiration_year: card&.exp_year,
            card_holder_name: nil,
            issuer: nil
          ).to_h
        end

        def update_stripe_customer_default_payment_method
          ::Stripe::Customer.update(
            stripe_customer_id,
            {invoice_settings: {default_payment_method: payment_method_id}},
            {api_key: stripe_payment_provider.secret_key}
          )
        end

        def customer
          @customer ||= stripe_customer.customer
        end

        def stripe_payment_provider
          @stripe_payment_provider ||= payment_provider(customer)
        end
      end
    end
  end
end
