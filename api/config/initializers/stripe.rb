# frozen_string_literal: true

Stripe.api_version = ENV.fetch("STRIPE_API_VERSION", "2025-04-30.basil")

# Lago uses the key from PaymentProvider.secret_key because each org should have their own keys
# In development, we always use our sandbox key, and in the console we might need to use
# the Stripe client directly (ex: ::Stripe::Customer.retrieve('cus_xxx')) which throws
# a "No API key provided." error.
# The key should never be set outside of development env
if Rails.env.development?
  Stripe.api_key = ENV["STRIPE_API_KEY"]
end
