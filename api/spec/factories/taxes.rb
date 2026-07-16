# frozen_string_literal: true

FactoryBot.define do
  factory :tax do
    organization
    code { "vat-#{SecureRandom.uuid}" }
    description { "French Standard VAT" }
    name { "VAT" }
    rate { 20.0 }
    # NOTE: usage of applied_to_organization is deprecated. Please, use :applied_to_billing_entity trait instead
    applied_to_organization { false }
    auto_generated { false }

    trait :applied_to_billing_entity do
      transient do
        billing_entity { nil }
      end

      after(:create) do |tax, evaluator|
        billing_entity = evaluator.billing_entity || tax.organization.default_billing_entity
        create(:billing_entity_applied_tax, tax:, billing_entity:, organization: tax.organization)
      end
    end
  end
end
