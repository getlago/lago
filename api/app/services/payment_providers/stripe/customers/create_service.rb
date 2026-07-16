# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Customers
      class CreateService < BaseService
        def initialize(customer:, payment_provider_id:, params:, async: true)
          @customer = customer
          @payment_provider_id = payment_provider_id
          @params = params || {}
          @async = async

          super
        end

        def call
          provider_customer = PaymentProviderCustomers::StripeCustomer.find_by(customer_id: customer.id)
          provider_customer ||= PaymentProviderCustomers::StripeCustomer.new(
            customer_id: customer.id,
            payment_provider_id:,
            organization_id: organization.id
          )

          if params.key?(:provider_customer_id)
            provider_customer.provider_customer_id = params[:provider_customer_id].presence
          end

          if params.key?(:sync_with_provider)
            provider_customer.sync_with_provider = params[:sync_with_provider].presence
          end

          provider_customer = handle_provider_payment_methods(provider_customer:, params:)
          provider_customer.save!

          result.provider_customer = provider_customer

          if should_create_provider_customer?
            create_customer_on_provider_service(async)
          elsif should_generate_checkout_url?
            generate_checkout_url(async)
          end

          if should_fetch_payment_method?
            FetchDefaultPaymentMethodJob.perform_later(provider_customer)
          end

          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_accessor :customer, :payment_provider_id, :params, :async

        delegate :organization, to: :customer

        def handle_provider_payment_methods(provider_customer:, params:)
          provider_payment_methods = (params || {})[:provider_payment_methods]

          if provider_customer.persisted?
            provider_customer.provider_payment_methods = provider_payment_methods if provider_payment_methods.present?
          else
            provider_customer.provider_payment_methods = provider_payment_methods.presence || %w[card]
          end

          provider_customer
        end

        def create_customer_on_provider_service(async)
          return PaymentProviderCustomers::StripeCreateJob.perform_later(result.provider_customer) if async

          PaymentProviderCustomers::StripeCreateJob.perform_now(result.provider_customer)
        end

        def generate_checkout_url(async)
          return PaymentProviderCustomers::StripeCheckoutUrlJob.perform_after_commit(result.provider_customer) if async

          PaymentProviderCustomers::StripeCheckoutUrlJob.perform_now(result.provider_customer)
        end

        def should_create_provider_customer?
          # NOTE: the customer does not exists on the service provider
          # and the customer id was not removed from the customer
          # customer sync with provider setting is set to true
          !result.provider_customer.provider_customer_id? &&
            !result.provider_customer.provider_customer_id_previously_changed? &&
            result.provider_customer.sync_with_provider.present?
        end

        def should_generate_checkout_url?
          !result.provider_customer.id_previously_changed?(from: nil) && # it was not created but updated
            result.provider_customer.provider_customer_id_previously_changed? &&
            result.provider_customer.provider_customer_id? &&
            result.provider_customer.sync_with_provider.blank? &&
            result.provider_customer.provider_payment_methods_require_setup?
        end

        def should_fetch_payment_method?
          !should_create_provider_customer? &&
            customer.payment_methods.empty? &&
            result.provider_customer.provider_customer_id?
        end
      end
    end
  end
end
