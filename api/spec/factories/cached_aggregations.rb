# frozen_string_literal: true

FactoryBot.define do
  factory :cached_aggregation do
    organization
    association :charge, factory: :standard_charge
    event_transaction_id { SecureRandom.uuid }
    external_subscription_id { SecureRandom.uuid }
    timestamp { Time.current }
  end
end
