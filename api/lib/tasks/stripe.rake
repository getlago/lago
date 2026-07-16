# frozen_string_literal: true

namespace :stripe do
  desc "Refresh stripe webhooks to add or remove an event type"
  task refresh_registered_webhooks: :environment do
    PaymentProviders::StripeProvider.unscoped.find_each do |stripe_provider|
      next unless stripe_provider.secret_key

      PaymentProviders::Stripe::RefreshWebhookJob.perform_later(stripe_provider)
    end
  end
end
