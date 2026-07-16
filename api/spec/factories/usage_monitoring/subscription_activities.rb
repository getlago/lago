# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_activity, class: "UsageMonitoring::SubscriptionActivity" do
    association :organization
    association :subscription
  end

  trait :enqueued do
    inserted_at { 3.minutes.ago }
    enqueued { true }
    enqueued_at { Time.current }
  end
end
