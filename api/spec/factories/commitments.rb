# frozen_string_literal: true

FactoryBot.define do
  factory :commitment do
    plan
    organization { plan&.organization || association(:organization) }
    commitment_type { "minimum_commitment" }
    amount_cents { 1_000 }
    invoice_display_name { Faker::Subscription.plan }

    trait :minimum_commitment do
      commitment_type { "minimum_commitment" }
    end
  end
end
