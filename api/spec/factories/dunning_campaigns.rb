# frozen_string_literal: true

FactoryBot.define do
  factory :dunning_campaign do
    organization
    name { Faker::Name.name }
    code { SecureRandom.uuid }
    days_between_attempts { Faker::Number.number(digits: 2) }
    max_attempts { Faker::Number.number(digits: 2) }
  end
end
