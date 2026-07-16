# frozen_string_literal: true

FactoryBot.define do
  factory :customer do
    organization
    billing_entity { organization&.default_billing_entity || association(:billing_entity) }
    name { Faker::TvShows::SiliconValley.character }
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }
    customer_type { nil }
    external_id { SecureRandom.uuid }
    country { Faker::Address.country_code }
    address_line1 { Faker::Address.street_address }
    address_line2 { Faker::Address.secondary_address }
    state { Faker::Address.state }
    zipcode { Faker::Address.zip_code }
    email { Faker::Internet.email }
    city { Faker::Address.city }
    url { Faker::Internet.url }
    phone { Faker::PhoneNumber.phone_number }
    logo_url { Faker::Internet.url }
    legal_name { Faker::Company.name }
    legal_number { Faker::Company.duns_number }
    currency { "EUR" }

    trait :with_shipping_address do
      shipping_address_line1 { Faker::Address.street_address }
      shipping_address_line2 { Faker::Address.secondary_address }
      shipping_city { Faker::Address.city }
      shipping_zipcode { Faker::Address.zip_code }
      shipping_state { Faker::Address.state }
      shipping_country { Faker::Address.country_code }
    end

    trait :with_same_billing_and_shipping_address do
      shipping_address_line1 { address_line1 }
      shipping_address_line2 { address_line2 }
      shipping_city { city }
      shipping_zipcode { zipcode }
      shipping_state { state }
      shipping_country { country }
    end

    trait :with_tax_integration do
      after :create do |customer|
        create(:anrok_customer, customer:)
      end
    end

    trait :with_hubspot_integration do
      after :create do |customer|
        create(:hubspot_customer, customer:)
      end
    end

    trait :with_salesforce_integration do
      after :create do |customer|
        create(:salesforce_customer, customer:)
      end
    end

    trait :with_inherited_invoice_custom_sections do
      organization { create(:organization, :with_invoice_custom_sections) }
    end

    trait :with_stripe_payment_provider do
      payment_provider { "stripe" }
      payment_provider_code { Faker::Lorem.word }

      after(:create) do |customer|
        payment_provider = build(
          :stripe_provider,
          organization: customer.organization,
          code: customer.payment_provider_code
        )

        create(:stripe_customer, customer:, payment_provider:)
      end
    end

    trait :with_static_values do
      with_same_billing_and_shipping_address

      firstname { "John" }
      lastname { "Doe" }
      name { "John Doe" }
      legal_name { "Doe Corp" }
      legal_number { "1234567890" }
      external_id { "customer_123" }
      email { "john.doe@example.com" }
      address_line1 { "456 Customer Ave" }
      address_line2 { "Apt 202" }
      city { "New York" }
      state { "NY" }
      zipcode { "10001" }
      country { "US" }
      phone { "+1-555-123-4567" }
    end
  end
end
