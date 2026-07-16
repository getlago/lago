# frozen_string_literal: true

module PaymentProviders
  module Cashfree
    module Payments
      class CreateService < BaseService
        include ::Customers::PaymentProviderFinder

        def initialize(payment:)
          @payment = payment
          @invoice = payment.payable
          @provider_customer = payment.payment_provider_customer

          super
        end

        def call
          result.payment = payment

          # NOTE: No need to register the payment with Cashfree Payments for the Payment Link feature.
          # Simply create a single `Payment` record and update it upon receiving the webhook, which works perfectly fine.

          result
        end

        private

        attr_reader :payment, :invoice, :provider_customer

        delegate :payment_provider, :customer, to: :provider_customer
      end
    end
  end
end
