# frozen_string_literal: true

FactoryBot.define do
  factory :billing_entity do
    name { Faker::Company.name }
    code { "entity_#{SecureRandom.uuid}" }
    default_currency { "USD" }

    email { Faker::Internet.email }
    email_settings { ["invoice.finalized", "credit_note.created"] }
    organization { association(:organization, billing_entities: [instance]) }

    trait :deleted do
      deleted_at { Time.current }
    end

    trait :archived do
      archived_at { Time.current }
    end

    trait :with_static_values do
      name { "ACME Corporation" }
      email { "billing@acme.com" }
      address_line1 { "123 Business St" }
      address_line2 { "Suite 100" }
      city { "San Francisco" }
      state { "CA" }
      zipcode { "94105" }
      country { "US" }
      document_number_prefix { "ACM-8924" }
    end
  end
end
