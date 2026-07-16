# frozen_string_literal: true

module PaymentProviderCustomers
  class GocardlessCreateJob < ApplicationJob
    queue_as :providers

    retry_on GoCardlessPro::GoCardlessError, wait: :polynomially_longer, attempts: 6
    retry_on GoCardlessPro::ApiError, wait: :polynomially_longer, attempts: 6
    retry_on GoCardlessPro::RateLimitError, wait: :polynomially_longer, attempts: 6
    retry_on ActiveJob::DeserializationError

    def perform(gocardless_customer)
      result = PaymentProviderCustomers::GocardlessService.new(gocardless_customer).create
      result.raise_if_error!
    end
  end
end
