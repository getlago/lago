# frozen_string_literal: true

FactoryBot.define do
  factory :fixed_charge_event do
    organization { subscription&.organization || association(:organization) }
    subscription
    fixed_charge
    units { "9.99" }
    timestamp { Time.current }
    deleted_at { nil }
  end
end
