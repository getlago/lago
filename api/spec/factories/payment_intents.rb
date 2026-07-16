# frozen_string_literal: true

FactoryBot.define do
  factory :payment_intent do
    invoice { association(:invoice) }
    organization { invoice.organization }
    payment_url { Faker::Internet.url }

    trait :expired do
      status { :expired }
      expires_at { generate(:past_date) }
    end

    trait :awaiting_expiration do
      expires_at { 1.hour.ago }
    end
  end
end
