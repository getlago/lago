# frozen_string_literal: true

FactoryBot.define do
  factory :quote do
    organization
    customer
    order_type { :subscription_creation }
    sequence(:sequential_id) { |n| n }

    trait :with_version do
      transient do
        version_trait { nil }
      end

      after(:create) do |quote, evaluator|
        traits = Array(evaluator.version_trait)
        create(
          :quote_version,
          *traits,
          quote: quote,
          organization: quote.organization
        )
      end
    end
  end
end
