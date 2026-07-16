# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_applied_invoice_custom_section, class: "Subscription::AppliedInvoiceCustomSection" do
    subscription
    organization { subscription&.organization || association(:organization) }
    invoice_custom_section { association(:invoice_custom_section, organization:) }
  end
end
