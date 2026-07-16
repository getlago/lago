# frozen_string_literal: true

class RefreshStripeWebhooks < ActiveRecord::Migration[7.1]
  # Stripe calls are external; avoid wrapping in a DB transaction.
  disable_ddl_transaction!

  def up
    PaymentProviders::StripeProvider.find_each do |stripe_provider|
      next unless stripe_provider.secret_key

      PaymentProviders::Stripe::RefreshWebhookJob.perform_later(stripe_provider)
    end
  end
end
