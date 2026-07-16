# frozen_string_literal: true

module PaymentProviderCustomers
  class MoneyhashCheckoutUrlJob < ApplicationJob
    queue_as :providers

    retry_on ActiveJob::DeserializationError

    def perform(moneyhash_customer)
      result = PaymentProviderCustomers::MoneyhashService.new(moneyhash_customer).generate_checkout_url
      result.raise_if_error!
    end
  end
end
