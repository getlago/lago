# frozen_string_literal: true

module PaymentProviders
  module Stripe
    class RefreshWebhookJob < ApplicationJob
      queue_as "providers"

      def perform(stripe_provider)
        PaymentProviders::Stripe::RefreshWebhookService.call!(stripe_provider)
      end
    end
  end
end
