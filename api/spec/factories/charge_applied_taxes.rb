# frozen_string_literal: true

FactoryBot.define do
  factory :charge_applied_tax, class: "Charge::AppliedTax" do
    association :charge, factory: :standard_charge
    tax
    organization { charge&.organization || tax&.organization || association(:organization) }
  end
end
