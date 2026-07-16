# frozen_string_literal: true

FactoryBot.define do
  factory :invoice_settlement do
    organization
    billing_entity
    association :target_invoice, factory: :invoice

    amount_cents { 10_000 }
    amount_currency { "EUR" }
    settlement_type { :payment }

    trait :with_payment do
      settlement_type { :payment }
      source_payment { association(:payment) }
    end

    trait :with_credit_note do
      settlement_type { :credit_note }
      source_credit_note { association(:credit_note) }
    end
  end
end
