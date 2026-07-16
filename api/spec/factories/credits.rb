# frozen_string_literal: true

FactoryBot.define do
  factory :credit do
    invoice
    applied_coupon
    organization { invoice&.organization || applied_coupon&.organization || association(:organization) }

    amount_cents { 200 }
    amount_currency { "EUR" }
  end

  factory :credit_note_credit, class: "Credit" do
    invoice
    credit_note
    organization { invoice&.organization || credit_note&.organization || association(:organization) }

    amount_cents { 200 }
    amount_currency { "EUR" }
  end

  factory :progressive_billing_invoice_credit, class: "Credit" do
    invoice
    progressive_billing_invoice factory: :invoice
    organization { invoice&.organization || association(:organization) }

    amount_cents { 200 }
    amount_currency { "EUR" }
  end
end
