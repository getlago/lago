# frozen_string_literal: true

module Invoices
  module Payments
    module PaymentProviders
      class Factory
        def self.new_instance(invoice:)
          service_class(invoice.customer&.payment_provider).new(invoice)
        end

        def self.service_class(payment_provider)
          case payment_provider&.to_s
          when "stripe"
            Invoices::Payments::StripeService
          when "adyen"
            Invoices::Payments::AdyenService
          when "gocardless"
            Invoices::Payments::GocardlessService
          when "cashfree"
            Invoices::Payments::CashfreeService
          when "flutterwave"
            Invoices::Payments::FlutterwaveService
          when "moneyhash"
            Invoices::Payments::MoneyhashService
          else
            raise(NotImplementedError)
          end
        end
      end
    end
  end
end
