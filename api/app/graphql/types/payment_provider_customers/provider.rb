# frozen_string_literal: true

module Types
  module PaymentProviderCustomers
    class Provider < Types::BaseObject
      graphql_name "ProviderCustomer"

      field :id, ID, null: false
      field :provider_customer_id, ID, null: true
      field :provider_payment_methods, [Types::PaymentProviderCustomers::ProviderPaymentMethodsEnum], null: true
      field :sync_with_provider, Boolean, null: true
    end
  end
end
