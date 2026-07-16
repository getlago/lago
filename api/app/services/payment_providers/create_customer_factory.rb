# frozen_string_literal: true

module PaymentProviders
  class CreateCustomerFactory
    def self.new_instance(provider:, customer:, payment_provider_id:, params:, async: true)
      service_class(provider:).new(customer:, payment_provider_id:, params:, async:)
    end

    def self.service_class(provider:)
      case provider
      when "adyen"
        PaymentProviders::Adyen::Customers::CreateService
      when "cashfree"
        PaymentProviders::Cashfree::Customers::CreateService
      when "flutterwave"
        PaymentProviders::Flutterwave::Customers::CreateService
      when "gocardless"
        PaymentProviders::Gocardless::Customers::CreateService
      when "stripe"
        PaymentProviders::Stripe::Customers::CreateService
      when "moneyhash"
        PaymentProviders::Moneyhash::Customers::CreateService
      end
    end
  end
end
