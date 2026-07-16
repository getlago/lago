# frozen_string_literal: true

FactoryBot.define do
  factory :stripe_provider, class: "PaymentProviders::StripeProvider" do
    organization
    type { "PaymentProviders::StripeProvider" }
    code { "stripe_account_#{SecureRandom.uuid}" }
    name { "Stripe Account 1" }

    secrets do
      {secret_key: SecureRandom.uuid}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :gocardless_provider, class: "PaymentProviders::GocardlessProvider" do
    organization
    type { "PaymentProviders::GocardlessProvider" }
    code { "gocardless_account_#{SecureRandom.uuid}" }
    name { "GoCardless Account 1" }

    secrets do
      {access_token: SecureRandom.uuid}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :adyen_provider, class: "PaymentProviders::AdyenProvider" do
    organization
    type { "PaymentProviders::AdyenProvider" }
    code { "adyen_account_#{SecureRandom.uuid}" }
    name { "Adyen Account 1" }

    secrets do
      {api_key:, hmac_key:}.to_json
    end

    settings do
      {live_prefix:, merchant_account:, success_redirect_url:}
    end

    transient do
      api_key { SecureRandom.uuid }
      merchant_account { Faker::Company.duns_number }
      live_prefix { Faker::Internet.domain_word }
      hmac_key { SecureRandom.uuid }
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :cashfree_provider, class: "PaymentProviders::CashfreeProvider" do
    organization
    type { "PaymentProviders::CashfreeProvider" }
    code { "cashfree_account_#{SecureRandom.uuid}" }
    name { "Cashfree Account 1" }

    secrets do
      {client_id: SecureRandom.uuid, client_secret: SecureRandom.uuid}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :moneyhash_provider, class: "PaymentProviders::MoneyhashProvider" do
    organization
    type { "PaymentProviders::MoneyhashProvider" }
    name { "MoneyHash" }
    code { "moneyhash_#{SecureRandom.uuid}" }

    secrets do
      {api_key:}.to_json
    end

    settings do
      {success_redirect_url:, flow_id:}
    end

    transient do
      api_key { SecureRandom.uuid }
      success_redirect_url { Faker::Internet.url }
      flow_id { SecureRandom.uuid[0..19] }
    end
  end
  factory :flutterwave_provider, class: "PaymentProviders::FlutterwaveProvider" do
    organization
    type { "PaymentProviders::FlutterwaveProvider" }
    name { "Flutterwave" }
    code { "flutterwave_#{SecureRandom.uuid}" }
    secrets do
      {secret_key:, webhook_secret:}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      secret_key { "FLWSECK-#{SecureRandom.uuid}" }
      success_redirect_url { Faker::Internet.url }
      webhook_secret { SecureRandom.hex(32) }
    end
  end
end
