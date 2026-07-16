# frozen_string_literal: true

FactoryBot.define do
  factory :payment_method do
    association :payment_provider_customer, factory: :stripe_customer
    payment_provider { payment_provider_customer&.payment_provider || association(:stripe_provider) }
    organization { payment_provider_customer&.organization || association(:organization) }
    customer { payment_provider_customer&.customer || association(:customer) }
    provider_method_id { "ext_123" }
    provider_method_type { "card" }
    is_default { true }

    details do
      {last4: "9876", brand: "Visa"}
    end
  end
end
