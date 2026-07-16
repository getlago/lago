# frozen_string_literal: true

FactoryBot.define do
  factory :quote_version do
    quote
    organization { quote.organization }
    status { :draft }
    sequence(:sequential_id) { |n| n }

    trait :approved do
      status { :approved }
      approved_at { Time.current }
    end

    trait :voided do
      status { :voided }
      voided_at { Time.current }
      void_reason { :manual }
    end
  end
end
