# frozen_string_literal: true

FactoryBot.define do
  factory :applied_add_on do
    customer
    add_on

    amount_cents { 200 }
    amount_currency { "EUR" }
  end
end
