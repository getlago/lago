# frozen_string_literal: true

module PaymentProviderCustomers
  class AdyenCheckoutUrlJob < ApplicationJob
    queue_as :providers

    retry_on Adyen::AdyenError, wait: :polynomially_longer, attempts: 6
    retry_on ActiveJob::DeserializationError

    def perform(adyen_customer)
      result = PaymentProviderCustomers::AdyenService.new(adyen_customer).generate_checkout_url
      result.raise_if_error!
    end
  end
end
