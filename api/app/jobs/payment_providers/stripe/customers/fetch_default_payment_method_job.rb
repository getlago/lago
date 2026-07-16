# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Customers
      class FetchDefaultPaymentMethodJob < ApplicationJob
        queue_as :default

        retry_on ::Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5

        def perform(provider_customer)
          PaymentProviders::Stripe::Customers::FetchDefaultPaymentMethodService.call!(provider_customer:)
        end
      end
    end
  end
end
