# frozen_string_literal: true

FactoryBot.define do
  factory :pricing_unit_usage do
    organization { fee&.organization || pricing_unit&.organization || association(:organization) }
    fee
    pricing_unit
    short_name { pricing_unit.short_name }
    amount_cents { 200 }
    precise_amount_cents { BigDecimal("200.0000000001") }
    unit_amount_cents { 10 }
    precise_unit_amount { 0.1 }
    conversion_rate { 1.0 }
  end
end
