# frozen_string_literal: true

FactoryBot.define do
  factory :pricing_unit do
    organization { association(:organization, pricing_units: []) }
    name { [Faker::Emotion.adjective, Faker::Currency.name].join(" ") }
    code { Faker::Lorem.unique.word }
    short_name { Faker::CryptoCoin.coin_name.first(3) }
  end
end
