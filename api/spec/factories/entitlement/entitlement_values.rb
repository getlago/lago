# frozen_string_literal: true

FactoryBot.define do
  factory :entitlement_value, class: "Entitlement::EntitlementValue" do
    organization { entitlement&.organization || privilege&.organization || association(:organization) }
    association :privilege, factory: :privilege
    association :entitlement, factory: :entitlement
    value { "test_value" }
  end
end
