# frozen_string_literal: true

FactoryBot.define do
  factory :webhook do
    association :webhook_endpoint, factory: :webhook_endpoint
    association :object, factory: :invoice
    organization { webhook_endpoint&.organization || object&.organization || association(:organization) }

    payload { Faker::Types.rb_hash(number: 3) }
    webhook_type { "invoice.created" }
    endpoint { Faker::Internet.url }

    trait :succeeded do
      http_status { 200 }
      status { :succeeded }
      retries { 0 }
    end

    trait :succeeded_with_retries do
      http_status { 200 }
      status { :succeeded }
      retries { Faker::Number.between(from: 1, to: 20) }
      last_retried_at { Time.zone.now - 3.minutes }
    end

    trait :retrying do
      status { :retrying }
      response { Faker::Json.shallow_json(width: 1) }
    end

    trait :retrying_with_retries do
      status { :retrying }
      retries { Faker::Number.between(from: 1, to: 20) }
      last_retried_at { Time.zone.now - 3.minutes }
      response { Faker::Json.shallow_json(width: 1) }
    end

    trait :failed do
      http_status { 500 }
      status { :failed }
      response { Faker::Json.shallow_json(width: 1) }
    end

    trait :failed_with_retries do
      http_status { 500 }
      status { :failed }
      retries { Faker::Number.between(from: 1, to: 20) }
      last_retried_at { Time.zone.now - 3.minutes }
      response { Faker::Json.shallow_json(width: 1) }
    end

    trait :pending do
      status { :pending }
    end
  end
end
