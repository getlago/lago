# frozen_string_literal: true

FactoryBot.define do
  factory :privilege, class: "Entitlement::Privilege" do
    organization { feature&.organization || association(:organization) }
    association :feature, factory: :feature
    sequence(:code) { |n| "privilege_#{n}" }
    name { nil }
    value_type { "string" }
    config { {} }
  end

  trait :integer_type do
    code { "int" }
    value_type { "integer" }
  end

  trait :string_type do
    code { "str" }
    value_type { "string" }
  end

  trait :boolean_type do
    code { "bool" }
    value_type { "boolean" }
  end

  trait :select_type do
    code { "opt" }
    value_type { "select" }
    config { {select_options: ["option1", "option2", "option3"]} }
  end
end
