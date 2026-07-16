# frozen_string_literal: true

FactoryBot.define do
  factory :fee_applied_tax, class: "Fee::AppliedTax" do
    fee
    tax
    organization { fee&.organization || tax&.organization || association(:organization) }

    tax_code { tax&.code.presence || "vat-#{SecureRandom.uuid}" }
    tax_description { "French Standard VAT" }
    tax_name { "VAT" }
    tax_rate { 20.0 }
    amount_cents { 200 }
    amount_currency { "EUR" }
    transient do
      provider_tax_breakdown_object { nil }
    end

    trait :with_provider_tax do
      tax_description { provider_tax_breakdown_object.type }
      tax_code { provider_tax_breakdown_object.name.parameterize(separator: "_") }
      tax_name { provider_tax_breakdown_object.name }
      tax_rate { provider_tax_breakdown_object.rate }
    end
  end
end
