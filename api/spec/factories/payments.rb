# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    association :payable, factory: :invoice
    association :payment_provider, factory: :stripe_provider
    association :payment_provider_customer, factory: :stripe_customer
    organization { payable&.organization || payment_provider&.organization || association(:organization) }
    customer { payable&.customer || association(:customer) }

    amount_cents { 200 }
    amount_currency { "EUR" }
    provider_payment_id { SecureRandom.uuid }
    status { "pending" }
    payable_payment_status { "pending" }
    payment_type { "provider" }

    trait :adyen_payment do
      association :payment_provider, factory: :adyen_provider
      association :payment_provider_customer, factory: :adyen_customer
    end

    trait :gocardless_payment do
      association :payment_provider, factory: :gocardless_provider
      association :payment_provider_customer, factory: :gocardless_customer
    end

    trait :cashfree_payment do
      association :payment_provider, factory: :cashfree_provider
      association :payment_provider_customer, factory: :cashfree_customer
    end

    trait :requires_action do
      status { "requires_action" }
      provider_payment_data do
        {
          redirect_to_url: {url: "https://foo.bar"}
        }
      end
    end
  end
end
