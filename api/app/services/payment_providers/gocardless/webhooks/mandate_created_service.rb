# frozen_string_literal: true

module PaymentProviders
  module Gocardless
    module Webhooks
      class MandateCreatedService < BaseService
        Result = BaseResult[:payment_method]

        def initialize(payment_provider:, mandate_id:)
          @payment_provider = payment_provider
          @mandate_id = mandate_id

          super
        end

        def call
          mandate = fetch_mandate
          return result unless mandate

          gocardless_customer = find_gocardless_customer(mandate.links.customer)
          return result unless gocardless_customer

          create_payment_method(gocardless_customer, mandate)

          result
        end

        private

        attr_reader :payment_provider, :mandate_id

        def fetch_mandate
          client.mandates.get(mandate_id)
        rescue GoCardlessPro::Error
          nil
        end

        def find_gocardless_customer(provider_customer_id)
          PaymentProviderCustomers::GocardlessCustomer.find_by(
            organization: payment_provider.organization,
            provider_customer_id:
          )
        end

        def create_payment_method(gocardless_customer, mandate)
          gocardless_customer.provider_mandate_id = mandate.id
          gocardless_customer.save!

          result.payment_method = PaymentMethods::FindOrCreateFromProviderService.call(
            customer: gocardless_customer.customer,
            payment_provider_customer: gocardless_customer,
            provider_method_id: mandate.id,
            params: {
              provider_payment_methods: gocardless_customer.provider_payment_methods
            },
            set_as_default: true
          ).payment_method
        end

        def client
          @client ||= GoCardlessPro::Client.new(
            access_token: payment_provider.access_token,
            environment: payment_provider.environment
          )
        end
      end
    end
  end
end
