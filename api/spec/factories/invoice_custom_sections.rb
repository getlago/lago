# frozen_string_literal: true

FactoryBot.define do
  factory :invoice_custom_section do
    organization
    code { Faker::Lorem.words(number: 3).join("_") }
    name { Faker::Lorem.words(number: 3).join(" ") }
    display_name { Faker::Lorem.words(number: 3).join(" ") }
    details { "These details are shown in the invoice" }

    trait :system_generated do
      section_type { "system_generated" }
    end
  end
end
