# frozen_string_literal: true

module PaymentProviderCustomers
  class StripeSyncFundingInstructionsJob < ApplicationJob
    queue_as :providers

    retry_on ::Stripe::APIConnectionError, wait: :polynomially_longer, attempts: 6
    retry_on ::Stripe::APIError, wait: :polynomially_longer, attempts: 6
    retry_on ::Stripe::RateLimitError, wait: :polynomially_longer, attempts: 6
    retry_on ActiveJob::DeserializationError

    def perform(stripe_customer)
      result = PaymentProviderCustomers::Stripe::SyncFundingInstructionsService.new(stripe_customer).call
      result.raise_if_error!
    rescue BaseService::UnauthorizedFailure => e
      Rails.logger.warn(e.message)
    end
  end
end
