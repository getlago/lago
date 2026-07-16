# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Webhooks
      class CustomerUpdatedService < BaseService
        def call
          unless stripe_customer
            return result if deleted_stripe_customer.present?
            return handle_missing_customer
          end

          PaymentProviderCustomers::Stripe::UpdatePaymentMethodService.call(
            stripe_customer:,
            payment_method_id: payment_method_id
          )
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        def stripe_customer_id
          event.data.object.id
        end

        def stripe_customer_scope
          PaymentProviderCustomers::StripeCustomer
            .by_provider_id_from_organization(organization.id, stripe_customer_id)
        end

        def stripe_customer
          @stripe_customer ||= stripe_customer_scope.first
        end

        def deleted_stripe_customer
          stripe_customer_scope.with_discarded.discarded.first
        end

        def payment_method_id
          event.data.object.invoice_settings.default_payment_method || event.data.object.default_source
        end
      end
    end
  end
end
