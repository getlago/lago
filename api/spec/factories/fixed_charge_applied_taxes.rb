# frozen_string_literal: true

FactoryBot.define do
  factory :fixed_charge_applied_tax, class: "FixedCharge::AppliedTax" do
    fixed_charge
    tax
    organization { fixed_charge.organization || create(:organization) }
  end
end
