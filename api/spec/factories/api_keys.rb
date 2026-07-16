# frozen_string_literal: true

FactoryBot.define do
  factory :api_key do
    name { "API Key" }
    organization { association(:organization, api_keys: []) }

    trait :expired do
      expires_at { generate(:past_date) }
    end

    trait :expiring do
      expires_at { generate(:future_date) }
    end
  end
end
