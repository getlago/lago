# frozen_string_literal: true

module PaymentProviders
  module Stripe
    class RegisterWebhookJob < ApplicationJob
      queue_as "providers"

      def perform(stripe_provider)
        PaymentProviders::Stripe::RegisterWebhookService.call!(stripe_provider)
      end
    end
  end
end
