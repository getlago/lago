# frozen_string_literal: true

FactoryBot.define do
  factory :plan_applied_tax, class: "Plan::AppliedTax" do
    plan
    tax
    organization { plan&.organization || tax&.organization || association(:organization) }
  end
end
