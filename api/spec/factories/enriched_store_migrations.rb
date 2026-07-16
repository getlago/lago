# frozen_string_literal: true

FactoryBot.define do
  factory :enriched_store_migration do
    organization

    trait :checking do
      status { :checking }
      started_at { Time.current }
    end

    trait :processing do
      status { :processing }
      started_at { Time.current }
    end

    trait :enabling do
      status { :enabling }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
    end

    trait :failed do
      status { :failed }
      started_at { Time.current }
      error_message { "Something went wrong" }
    end
  end
end
