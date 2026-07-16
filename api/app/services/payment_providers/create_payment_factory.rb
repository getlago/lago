# frozen_string_literal: true

module PaymentProviders
  class CreatePaymentFactory
    def self.new_instance(provider:, payment:, reference:, metadata:)
      service_class(provider:).new(payment:, reference:, metadata:)
    end

    def self.service_class(provider:)
      case provider.to_sym
      when :adyen
        PaymentProviders::Adyen::Payments::CreateService
      when :cashfree
        PaymentProviders::Cashfree::Payments::CreateService
      when :gocardless
        PaymentProviders::Gocardless::Payments::CreateService
      when :stripe
        PaymentProviders::Stripe::Payments::CreateService
      when :moneyhash
        PaymentProviders::Moneyhash::Payments::CreateService
      end
    end
  end
end
