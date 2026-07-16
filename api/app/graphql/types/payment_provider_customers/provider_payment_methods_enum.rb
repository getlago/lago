# frozen_string_literal: true

module Types
  module PaymentProviderCustomers
    class ProviderPaymentMethodsEnum < Types::BaseEnum
      ::PaymentProviderCustomers::StripeCustomer::PAYMENT_METHODS.each do |type|
        value type
      end
    end
  end
end
