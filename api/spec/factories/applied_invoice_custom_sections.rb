# frozen_string_literal: true

FactoryBot.define do
  factory :applied_invoice_custom_section do
    invoice
    organization { invoice&.organization || association(:organization) }
    code { Faker::Lorem.words(number: 3).join("_") }
    name { Faker::Lorem.words(number: 3).join(" ") }
    display_name { Faker::Lorem.words(number: 3).join(" ") }
    details { "These details are shown in the invoice" }
  end
end
