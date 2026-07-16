# frozen_string_literal: true

FactoryBot.define do
  factory :billing_entity_applied_tax, class: "BillingEntity::AppliedTax" do
    billing_entity
    tax
    organization { billing_entity&.organization || tax&.organization || association(:organization) }
  end
end
