# frozen_string_literal: true

FactoryBot.define do
  factory :usage_threshold do
    plan
    subscription { nil }
    organization { plan&.organization || subscription&.organization || association(:organization) }
    threshold_display_name { Faker::Name.name }
    amount_cents { 100 }
    recurring { false }

    trait :recurring do
      recurring { true }
    end

    trait :for_subscription do
      plan { nil }
      subscription
    end
  end
end
