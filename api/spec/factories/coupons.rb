# frozen_string_literal: true

FactoryBot.define do
  factory :coupon do
    organization
    name { Faker::Name.name }
    code { Faker::Alphanumeric.alphanumeric(number: 10) }
    coupon_type { "fixed_amount" }
    status { "active" }
    expiration { "no_expiration" }
    amount_cents { 200 }
    amount_currency { "EUR" }
    frequency { "once" }
    description { "Coupon Description" }

    trait :deleted do
      deleted_at { 1.day.ago }
    end
  end
end
