# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    transient do
      with_static_values { false }
    end

    name { Faker::Company.name }
    sequence(:slug) { |n| "test-org-#{n}" }
    default_currency { "USD" }
    audit_logs_period { nil }

    email { Faker::Internet.email }
    email_settings { ["invoice.finalized", "credit_note.created"] }

    api_keys { [association(:api_key, organization: instance, strategy: :build)] }
    billing_entities do
      [
        association(
          :billing_entity,
          *(with_static_values ? [:with_static_values] : []),
          organization: instance,
          strategy: :build
        )
      ]
    end

    transient do
      webhook_url { Faker::Internet.url }
    end

    after(:create) do |organization, evaluator|
      # because we're building billing entity while building the organization, possible that the billing_entity will be
      # created att he same moment as the organization, so we need to reload it to get the correct scope
      organization.reload
      if evaluator.webhook_url
        organization.webhook_endpoints.create!(webhook_url: evaluator.webhook_url)
      end
    end

    trait :premium do
      premium_integrations { Organization::PREMIUM_INTEGRATIONS }
    end

    trait :with_invoice_custom_sections do
      after :create do |org|
        create_list(:invoice_custom_section, 3, organization: org)
      end
    end

    trait :with_default_dunning_campaign do
      after :create do |org|
        create(:dunning_campaign, organization: org, applied_to_organization: true)
      end
    end

    trait :with_static_values do
      with_static_values { true }

      name { "ACME Corporation" }
      slug { "acme-corp" }
      default_currency { "USD" }
      country { "US" }
    end
  end
end
