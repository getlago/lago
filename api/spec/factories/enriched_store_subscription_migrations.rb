# frozen_string_literal: true

FactoryBot.define do
  factory :enriched_store_subscription_migration do
    enriched_store_migration
    organization { enriched_store_migration&.organization || association(:organization) }
    subscription { association(:subscription, organization: organization) }

    trait :comparing do
      status { :comparing }
      started_at { Time.current }
    end

    trait :reprocessing do
      status { :reprocessing }
      started_at { Time.current }
    end

    trait :waiting_for_enrichment do
      status { :waiting_for_enrichment }
      started_at { Time.current }
    end

    trait :deduplicating do
      status { :deduplicating }
      started_at { Time.current }
    end

    trait :dedup_paused do
      status { :dedup_paused }
      started_at { Time.current }
      dedup_pending_queries { ["DELETE FROM events_enriched_expanded..."] }
    end

    trait :validating do
      status { :validating }
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
