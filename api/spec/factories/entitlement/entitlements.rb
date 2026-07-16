# frozen_string_literal: true

FactoryBot.define do
  factory :entitlement, class: "Entitlement::Entitlement" do
    organization { feature&.organization || plan&.organization || association(:organization) }
    association :feature, factory: :feature
    association :plan

    trait :subscription do
      plan { nil }
      association :subscription
    end
  end
end
