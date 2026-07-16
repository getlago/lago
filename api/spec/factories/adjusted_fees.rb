# frozen_string_literal: true

FactoryBot.define do
  factory :adjusted_fee do
    organization { invoice&.organization || fee&.organization || association(:organization) }
    invoice
    fee
    charge { nil }
    subscription

    fee_type { "subscription" }

    unit_amount_cents { 200 }
    units { 2 }
    adjusted_amount { true }

    invoice_display_name { Faker::Fantasy::Tolkien.character }
  end
end
