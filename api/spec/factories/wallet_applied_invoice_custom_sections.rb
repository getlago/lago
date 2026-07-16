# frozen_string_literal: true

FactoryBot.define do
  factory :wallet_applied_invoice_custom_section, class: "Wallet::AppliedInvoiceCustomSection" do
    wallet
    organization { wallet&.organization || association(:organization) }
    invoice_custom_section { association(:invoice_custom_section, organization:) }
  end
end
