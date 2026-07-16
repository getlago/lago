# frozen_string_literal: true

FactoryBot.define do
  factory :credit_note_applied_tax, class: "CreditNote::AppliedTax" do
    credit_note
    tax
    organization { credit_note&.organization || tax&.organization || association(:organization) }
    tax_code { "vat-#{SecureRandom.uuid}" }
    tax_description { "French Standard VAT" }
    tax_name { "VAT" }
    tax_rate { 20.0 }
    amount_cents { 200 }
    amount_currency { "EUR" }
  end
end
