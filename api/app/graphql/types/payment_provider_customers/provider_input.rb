# frozen_string_literal: true

module Types
  module PaymentProviderCustomers
    class ProviderInput < BaseInputObject
      graphql_name "ProviderCustomerInput"

      argument :provider_customer_id, ID, required: false
      argument :provider_payment_methods, [Types::PaymentProviderCustomers::ProviderPaymentMethodsEnum], required: false
      argument :sync_with_provider, Boolean, required: false
    end
  end
end
