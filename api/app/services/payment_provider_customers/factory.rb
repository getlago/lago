# frozen_string_literal: true

module PaymentProviderCustomers
  class Factory
    def self.new_instance(provider_customer:)
      service_class(provider_customer).new(provider_customer)
    end

    def self.service_class(provider_customer)
      case provider_customer&.class.to_s
      when "PaymentProviderCustomers::StripeCustomer"
        PaymentProviderCustomers::StripeService
      when "PaymentProviderCustomers::GocardlessCustomer"
        PaymentProviderCustomers::GocardlessService
      when "PaymentProviderCustomers::CashfreeCustomer"
        PaymentProviderCustomers::CashfreeService
      when "PaymentProviderCustomers::FlutterwaveCustomer"
        PaymentProviderCustomers::FlutterwaveService
      when "PaymentProviderCustomers::AdyenCustomer"
        PaymentProviderCustomers::AdyenService
      when "PaymentProviderCustomers::MoneyhashCustomer"
        PaymentProviderCustomers::MoneyhashService
      else
        raise(NotImplementedError)
      end
    end
  end
end
