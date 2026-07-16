# frozen_string_literal: true

FactoryBot.define do
  factory :applied_pricing_unit do
    pricing_unit
    pricing_unitable { association(:standard_charge) }
    organization { pricing_unit&.organization || pricing_unitable&.organization || association(:organization) }
    conversion_rate { rand(1.0..10.0) }
  end
end
