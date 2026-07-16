# frozen_string_literal: true

FactoryBot.define do
  factory :wallet_transaction_applied_invoice_custom_section, class: "WalletTransaction::AppliedInvoiceCustomSection" do
    wallet_transaction
    organization { wallet_transaction&.organization || association(:organization) }
    invoice_custom_section { association(:invoice_custom_section, organization:) }
  end
end
