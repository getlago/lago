# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    customer
    plan
    organization { customer&.organization || plan&.organization || association(:organization) }
    status { :active }
    external_id { SecureRandom.uuid }
    started_at { 1.day.ago }
    activated_at { 1.day.ago }
    subscription_at { 1.day.ago }

    trait :pending do
      status { :pending }
      started_at { nil }
      activated_at { nil }
    end

    trait :canceled do
      status { :canceled }
      canceled_at { Time.current }
    end

    trait :terminated do
      status { :terminated }
      started_at { 1.month.ago }
      activated_at { 1.month.ago }
      terminated_at { Time.zone.now }
    end

    trait :incomplete do
      status { :incomplete }
      started_at { Time.current }
      activated_at { nil }
    end

    trait :calendar do
      billing_time { :calendar }
    end

    trait :anniversary do
      billing_time { :anniversary }
    end

    trait :with_previous_subscription do
      previous_subscription { association(:subscription, customer:, plan:, organization:) }
    end

    trait :with_activation_rules do
      transient do
        activation_rules_config { [{type: "payment", timeout_hours: 48}] }
      end

      after(:create) do |subscription, evaluator|
        evaluator.activation_rules_config.each do |config|
          create(:subscription_activation_rule, subscription:, organization: subscription.organization, **config)
        end
      end
    end
  end
end
