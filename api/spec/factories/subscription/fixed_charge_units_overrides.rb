# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_fixed_charge_units_override, class: "Subscription::FixedChargeUnitsOverride" do
    subscription
    organization { subscription&.organization || association(:organization) }
    fixed_charge
    units { Faker::Number.between(from: 0, to: 100) }
  end
end
