# frozen_string_literal: true

module PaymentIntents
  class ExpireJob < ApplicationJob
    queue_as "providers"

    retry_on ::Stripe::RateLimitError, ::Stripe::APIConnectionError, wait: :polynomially_longer, attempts: 5

    def perform(invoice)
      PaymentIntents::ExpireService.call!(invoice:)
    end
  end
end
