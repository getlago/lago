# frozen_string_literal: true

module PaymentProviders
  class CancelPaymentAuthorizationJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
        :payments
      else
        :providers
      end
    end

    def perform(payment_provider:, id:)
      provider_name = payment_provider.payment_type.to_s

      case provider_name
      when "stripe"
        ::Stripe::PaymentIntent.cancel(id, {}, api_key: payment_provider.secret_key)
      else
        raise NotImplementedError.new("Cancelling payment authorization not implemented for #{provider_name}")
      end
    end
  end
end
