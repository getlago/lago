# frozen_string_literal: true

FactoryBot.define do
  factory :feature, class: "Entitlement::Feature" do
    association :organization
    sequence(:code) { |n| "feature_#{n}" }
    name { "Feature Name" }
    description { "Feature Description" }
  end
end
