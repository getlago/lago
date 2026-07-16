# frozen_string_literal: true

FactoryBot.define do
  factory :lifetime_usage do
    organization
    subscription

    current_usage_amount_cents { 0 }
    invoiced_usage_amount_cents { 0 }
    recalculate_current_usage { false }
    recalculate_invoiced_usage { false }
  end
end
